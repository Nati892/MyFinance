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

import { HouseholdStateService } from '../../services/household-state.service';
import { CategoryService } from '../../services/category.service';
import { TransactionService } from '../../services/transaction.service';

@Component({
  selector: 'app-app-incomes',
  standalone: true,
  imports: [CommonModule, FormsModule, CategorySidebarComponent, TimelineComponent],
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
  form = {
    amount: null as number | null,
    incomeCategoryId: null as number | null,
    dateTime: '',
    paymentMethod: 'credit_card',
    description: '',
    note: '',
  };

  readonly paymentMethods = [
    { value: 'credit_card',   label: 'Credit Card' },
    { value: 'debit_card',    label: 'Debit Card'  },
    { value: 'cash',          label: 'Cash'        },
    { value: 'bank_transfer', label: 'Bank Transfer' },
  ];

  private sub = new Subscription();

  constructor(
    private householdState: HouseholdStateService,
    private categoryService: CategoryService,
    private transactionService: TransactionService,
    private cdr: ChangeDetectorRef,
  ) {}

  ngOnInit(): void {
    const household = this.householdState.getSelectedHousehold();
    if (household) {
      this.householdId   = household.householdId;
      this.householdName = household.householdName;
      this.loadCategories();
      this.loadIncomes();
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
        }
      })
    );
  }

  ngOnDestroy(): void {
    this.sub.unsubscribe();
  }

  // ── Data loading ─────────────────────────────────────────────────────────────

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

    // Format dateTime for datetime-local input (YYYY-MM-DDTHH:mm)
    const dt = new Date(tx.dateTime);
    const pad = (n: number) => String(n).padStart(2, '0');
    const localDT =
      `${dt.getFullYear()}-${pad(dt.getMonth() + 1)}-${pad(dt.getDate())}` +
      `T${pad(dt.getHours())}:${pad(dt.getMinutes())}`;

    this.form = {
      amount:           tx.amount,
      incomeCategoryId: tx.category?.id ?? null,
      dateTime:         localDT,
      paymentMethod:    tx.paymentMethod,
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

    const now = new Date();
    const pad = (n: number) => String(n).padStart(2, '0');
    const localDT =
      `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}` +
      `T${pad(now.getHours())}:${pad(now.getMinutes())}`;

    this.form = {
      amount:           null,
      incomeCategoryId: categoryId ?? this.selectedCategoryId ?? this.categories[0]?.id ?? null,
      dateTime:         localDT,
      paymentMethod:    'credit_card',
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

    const payload = {
      amount:           this.form.amount,
      dateTime:         new Date(this.form.dateTime).toISOString(),
      description:      this.form.description || undefined,
      note:             this.form.note || undefined,
      paymentMethod:    this.form.paymentMethod,
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

  getCategoryById(id: number | null): Category | undefined {
    return this.categories.find(c => c.id === id);
  }
}
