import {
  Component,
  OnInit,
  OnDestroy,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subscription } from 'rxjs';

import {
  CategorySidebarComponent,
  Category,
  NewCategoryData,
} from '../../components/category-sidebar/category-sidebar.component';
import {
  TimelineComponent,
  TransactionItem,
  TimelineViewConfig,
} from '../../components/timeline/timeline.component';

import { TranslateModule } from '@ngx-translate/core';

import { HouseholdStateService } from '../../services/household-state.service';
import { CategoryService } from '../../services/category.service';
import { TransactionService } from '../../services/transaction.service';
import { CardService, Card } from '../../services/card.service';
import { LanguageService } from '../../services/language.service';

function toLocalDateTimeInput(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}`
  );
}

@Component({
  selector: 'app-app-incomes',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule, CategorySidebarComponent, TimelineComponent],
  templateUrl: './app-incomes.component.html',
  styleUrls: ['./app-incomes.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppIncomesComponent implements OnInit, OnDestroy {
  // ── Household ────────────────────────────────────────────────────────────────
  householdId: number | null = null;
  householdName = '';

  // ── Categories ───────────────────────────────────────────────────────────────
  categories: Category[] = [];
  favoriteCategories: Category[] = [];
  selectedCategoryId: number | null = null;

  // ── Transactions / timeline ───────────────────────────────────────────────────
  transactions: TransactionItem[] = [];
  loadingTransactions = false;
  loadError = false;

  // ── View config (mirrored from timeline) ────────────────────────────────────
  viewConfig: TimelineViewConfig = {
    view: 'monthly',
    periodOffset: 0,
  };

  // ── Modal state ──────────────────────────────────────────────────────────────
  showModal = false;
  isEditMode = false;
  editingId: number | null = null;
  saving = false;
  saveError = '';

  // ── Form model ───────────────────────────────────────────────────────────────
  form: {
    amount: number | null;
    incomeCategoryId: number | null;
    dateTime: string;
    paymentMethod: 'card' | 'cash' | 'bank_transfer';
    cardId: number | null;
    description: string;
    note: string;
  } = {
    amount: null,
    incomeCategoryId: null,
    dateTime: toLocalDateTimeInput(new Date()),
    paymentMethod: 'card',
    cardId: null,
    description: '',
    note: '',
  };

  readonly paymentMethods: { key: 'card' | 'cash' | 'bank_transfer'; label: string; emoji: string }[] = [
    { key: 'card',          label: 'Card',     emoji: '💳' },
    { key: 'cash',          label: 'Cash',     emoji: '💵' },
    { key: 'bank_transfer', label: 'Transfer', emoji: '🏦' },
  ];

  cards: Card[] = [];

  private sub = new Subscription();

  constructor(
    private householdState: HouseholdStateService,
    private categoryService: CategoryService,
    private transactionService: TransactionService,
    private cardService: CardService,
    private cdr: ChangeDetectorRef,
    private languageService: LanguageService,
  ) {}

  getCategoryDisplayName(cat: Category): string {
    if (this.languageService.currentLang === 'he' && cat.nameHe) return cat.nameHe;
    return cat.name;
  }

  ngOnInit(): void {
    const household = this.householdState.getSelectedHousehold();
    if (household) {
      this.householdId   = household.householdId;
      this.householdName = household.householdName;
      this.loadCategories();
      this.loadIncomes();
      this.loadCards();
    }

    this.sub.add(
      this.householdState.selectedHousehold$.subscribe(h => {
        if (!h) return;
        if (h.householdId !== this.householdId) {
          this.householdId   = h.householdId;
          this.householdName = h.householdName;
          this.selectedCategoryId = null;
          this.loadCategories();
          this.loadIncomes();
          this.loadCards();
        }
      })
    );
  }

  ngOnDestroy(): void {
    this.sub.unsubscribe();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

  private loadCards(): void {
    if (this.householdId == null) return;
    this.cardService.getCards(this.householdId).subscribe({
      next: res => {
        this.cards = res.cards ?? [];
        this.cdr.markForCheck();
      },
      error: () => {}
    });
  }

  private loadCategories(): void {
    if (!this.householdId) return;
    this.categoryService.getIncomeCategories(this.householdId).subscribe({
      next: res => {
        this.categories = res.categories ?? [];
        this.cdr.markForCheck();
      },
      error: () => {
        this.categories = [];
        this.cdr.markForCheck();
      },
    });
  }

  onCreateCategory(data: NewCategoryData): void {
    if (this.householdId == null) return;
    this.categoryService.createIncomeCategory({ ...data, householdId: this.householdId }).subscribe({
      next: () => this.loadCategories(),
      error: () => alert('Failed to create category. Please try again.'),
    });
  }

  loadIncomes(): void {
    if (!this.householdId) return;
    this.loadingTransactions = true;
    this.loadError = false;
    this.cdr.markForCheck();

    this.transactionService
      .getIncomes({
        householdId:  this.householdId,
        view:         this.viewConfig.view,
        periodOffset: this.viewConfig.periodOffset,
        weekNumber:   this.viewConfig.weekNumber,
        date:         this.viewConfig.date,
        categoryId:   this.selectedCategoryId,
      })
      .subscribe({
        next: res => {
          this.transactions = (res.incomes ?? []).map((i: any) => ({
            ...i,
            type: 'income' as const,
            category: i.IncomeCategory ?? i.incomeCategory,
            appUser:  i.AppUser ?? i.appUser,
          }));
          this.loadingTransactions = false;
          this.cdr.markForCheck();
        },
        error: () => {
          this.loadError = true;
          this.loadingTransactions = false;
          this.cdr.markForCheck();
        },
      });
  }

  // ── Sidebar event ────────────────────────────────────────────────────────────

  onCategorySelected(categoryId: number | null): void {
    this.selectedCategoryId = categoryId;
    this.loadIncomes();
    if (categoryId !== null) {
      this.openAddModal(categoryId);
    }
  }

  // ── Timeline events ──────────────────────────────────────────────────────────

  onViewChanged(config: TimelineViewConfig): void {
    this.viewConfig = config;
    this.loadIncomes();
  }

  onTransactionEdit(tx: TransactionItem): void {
    this.isEditMode  = true;
    this.editingId   = tx.id;
    this.saveError   = '';

    const pm = (tx.paymentMethod === 'credit_card' || tx.paymentMethod === 'debit_card')
      ? 'card' as const
      : tx.paymentMethod as 'card' | 'cash' | 'bank_transfer';

    this.form = {
      amount:           tx.amount,
      incomeCategoryId: tx.category?.id ?? null,
      dateTime:         toLocalDateTimeInput(new Date(tx.dateTime)),
      paymentMethod:    pm,
      cardId:           (tx as any).cardId ?? null,
      description:      tx.description ?? '',
      note:             tx.note ?? '',
    };
    this.showModal = true;
    this.cdr.markForCheck();
  }

  onTransactionDelete(tx: TransactionItem): void {
    if (!confirm(`Delete income of ₪${tx.amount}?`)) return;
    this.transactionService.deleteIncome(tx.id).subscribe({
      next: () => this.loadIncomes(),
      error: () => alert('Failed to delete income. Please try again.'),
    });
  }

  // ── Modal ────────────────────────────────────────────────────────────────────

  openAddModal(categoryId?: number): void {
    this.isEditMode  = false;
    this.editingId   = null;
    this.saveError   = '';

    this.form = {
      amount:           null,
      incomeCategoryId: categoryId ?? this.selectedCategoryId ?? this.categories[0]?.id ?? null,
      dateTime:         toLocalDateTimeInput(new Date()),
      paymentMethod:    'card',
      cardId:           null,
      description:      '',
      note:             '',
    };
    this.showModal = true;
    this.cdr.markForCheck();
  }

  closeModal(): void {
    this.showModal = false;
    this.saving    = false;
    this.saveError = '';
    this.cdr.markForCheck();
  }

  saveIncome(): void {
    if (!this.householdId) return;
    if (!this.form.amount || this.form.amount <= 0) {
      this.saveError = 'Please enter a valid amount.';
      return;
    }
    if (!this.form.incomeCategoryId) {
      this.saveError = 'Please select a category.';
      return;
    }
    if (!this.form.dateTime) {
      this.saveError = 'Please select a date and time.';
      return;
    }

    this.saving    = true;
    this.saveError = '';
    this.cdr.markForCheck();

    const payload: any = {
      amount:           this.form.amount,
      dateTime:         new Date(this.form.dateTime).toISOString(),
      description:      this.form.description || undefined,
      note:             this.form.note || undefined,
      paymentMethod:    this.form.paymentMethod,
      cardId:           this.form.paymentMethod === 'card' ? this.form.cardId : null,
      incomeCategoryId: this.form.incomeCategoryId!,
      householdId:      this.householdId,
    };

    const req$ = this.isEditMode && this.editingId != null
      ? this.transactionService.updateIncome(this.editingId, payload)
      : this.transactionService.createIncome(payload);

    req$.subscribe({
      next: () => {
        this.saving = false;
        this.closeModal();
        this.loadIncomes();
      },
      error: () => {
        this.saving    = false;
        this.saveError = 'Failed to save income. Please try again.';
        this.cdr.markForCheck();
      },
    });
  }

  // ── Template helpers ─────────────────────────────────────────────────────────

  selectChipCategory(id: number): void {
    this.form.incomeCategoryId = id;
  }

  selectCard(cardId: number | null): void {
    this.form.cardId = cardId;
  }

  getCardLabel(card: Card): string {
    return card.nickname ?? `••••${card.lastFourDigits}`;
  }

  onPaymentMethodChange(key: 'card' | 'cash' | 'bank_transfer'): void {
    this.form.paymentMethod = key;
    if (key !== 'card') this.form.cardId = null;
  }

  getCategoryById(id: number | null): Category | undefined {
    return this.categories.find(c => c.id === id);
  }
}
