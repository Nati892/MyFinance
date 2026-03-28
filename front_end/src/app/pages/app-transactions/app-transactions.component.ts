import { Component, OnInit, OnDestroy, ChangeDetectionStrategy, ChangeDetectorRef } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subscription, forkJoin } from 'rxjs';

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
import { LanguageService } from '../../services/language.service';

type ViewFilter = 'all' | 'expense' | 'income';
type ModalType = 'expense' | 'income';

interface TransactionForm {
  amount: number | null;
  categoryId: number | null;
  dateTime: string;
  paymentMethod: string;
  description: string;
  note: string;
}

function toLocalDateTimeInput(date: Date): string {
  const pad = (n: number) => String(n).padStart(2, '0');
  return (
    `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}` +
    `T${pad(date.getHours())}:${pad(date.getMinutes())}`
  );
}

@Component({
  selector: 'app-app-transactions',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule, CategorySidebarComponent, TimelineComponent],
  templateUrl: './app-transactions.component.html',
  styleUrls: ['./app-transactions.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppTransactionsComponent implements OnInit, OnDestroy {
  // ── Household ───────────────────────────────────────────────────────────────
  householdId: number | null = null;
  noHousehold = false;

  // ── Categories ──────────────────────────────────────────────────────────────
  expenseCategories: Category[] = [];
  incomeCategories: Category[] = [];
  expenseFavorites: Category[] = [];
  incomeFavorites: Category[] = [];
  categoriesError = false;
  selectedCategoryId: number | null = null;

  // ── Combined transactions ───────────────────────────────────────────────────
  allTransactions: TransactionItem[] = [];
  displayedTransactions: TransactionItem[] = [];
  transactionsLoading = false;
  transactionsError = false;

  // ── View config ─────────────────────────────────────────────────────────────
  viewConfig: TimelineViewConfig = {
    view: 'monthly',
    periodOffset: 0,
  };

  // ── Filter state ────────────────────────────────────────────────────────────
  viewFilter: ViewFilter = 'all';
  filterPanelOpen = false;
  filterMinAmount: number | null = null;
  filterMaxAmount: number | null = null;

  // ── Modal state ─────────────────────────────────────────────────────────────
  modalOpen = false;
  modalType: ModalType = 'expense';
  modalMode: 'add' | 'edit' = 'add';
  editingId: number | null = null;
  modalSaving = false;
  modalError: string | null = null;

  form: TransactionForm = {
    amount: null,
    categoryId: null,
    dateTime: toLocalDateTimeInput(new Date()),
    paymentMethod: 'credit_card',
    description: '',
    note: '',
  };

  readonly paymentMethods = [
    { key: 'credit_card',   label: 'Card',     emoji: '💳' },
    { key: 'debit_card',    label: 'Debit',    emoji: '💳' },
    { key: 'cash',          label: 'Cash',     emoji: '💵' },
    { key: 'bank_transfer', label: 'Transfer', emoji: '🏦' },
  ];

  private subs = new Subscription();

  constructor(
    private householdState: HouseholdStateService,
    private categoryService: CategoryService,
    private transactionService: TransactionService,
    private cdr: ChangeDetectorRef,
    private languageService: LanguageService,
  ) {}

  ngOnInit(): void {
    const household = this.householdState.getSelectedHousehold();
    if (!household) {
      this.noHousehold = true;
      return;
    }
    this.householdId = household.householdId;
    this.loadCategories();
    this.loadTransactions();

    this.subs.add(
      this.householdState.selectedHousehold$.subscribe(h => {
        if (h && h.householdId !== this.householdId) {
          this.householdId = h.householdId;
          this.noHousehold = false;
          this.selectedCategoryId = null;
          this.loadCategories();
          this.loadTransactions();
          this.cdr.markForCheck();
        }
      })
    );
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  private loadCategories(): void {
    if (this.householdId == null) return;
    this.categoriesError = false;

    this.categoryService.getExpenseCategories(this.householdId).subscribe({
      next: res => {
        this.expenseCategories = res.categories ?? [];
        this.cdr.markForCheck();
      },
      error: () => { this.categoriesError = true; this.cdr.markForCheck(); },
    });

    this.categoryService.getExpenseFavorites(this.householdId).subscribe({
      next: res => { this.expenseFavorites = res.favorites ?? []; this.cdr.markForCheck(); },
      error: () => {},
    });

    this.categoryService.getIncomeCategories(this.householdId).subscribe({
      next: res => {
        this.incomeCategories = res.categories ?? [];
        this.cdr.markForCheck();
      },
      error: () => {},
    });
  }

  onCreateExpenseCategory(data: NewCategoryData): void {
    if (this.householdId == null) return;
    this.categoryService.createExpenseCategory({ ...data, householdId: this.householdId }).subscribe({
      next: () => this.loadCategories(),
      error: () => alert('Failed to create category.'),
    });
  }

  onCreateIncomeCategory(data: NewCategoryData): void {
    if (this.householdId == null) return;
    this.categoryService.createIncomeCategory({ ...data, householdId: this.householdId }).subscribe({
      next: () => this.loadCategories(),
      error: () => alert('Failed to create category.'),
    });
  }

  loadTransactions(): void {
    if (this.householdId == null) return;
    this.transactionsLoading = true;
    this.transactionsError = false;

    const params = {
      householdId: this.householdId,
      view: this.viewConfig.view,
      periodOffset: this.viewConfig.periodOffset,
      weekNumber: this.viewConfig.weekNumber,
      date: this.viewConfig.date,
      categoryId: this.selectedCategoryId,
    };

    forkJoin({
      expenses: this.transactionService.getExpenses(params),
      incomes: this.transactionService.getIncomes(params),
    }).subscribe({
      next: ({ expenses, incomes }) => {
        const expenseItems: TransactionItem[] = (expenses.expenses ?? []).map((e: any) => ({
          ...e,
          type: 'expense' as const,
          category: e.ExpenseCategory ?? e.expenseCategory,
          appUser: e.AppUser ?? e.appUser,
        }));
        const incomeItems: TransactionItem[] = (incomes.incomes ?? []).map((i: any) => ({
          ...i,
          type: 'income' as const,
          category: i.IncomeCategory ?? i.incomeCategory,
          appUser: i.AppUser ?? i.appUser,
        }));

        // Merge and sort by date descending
        this.allTransactions = [...expenseItems, ...incomeItems].sort(
          (a, b) => new Date(b.dateTime).getTime() - new Date(a.dateTime).getTime()
        );
        this.applyFilters();
        this.transactionsLoading = false;
        this.cdr.markForCheck();
      },
      error: () => {
        this.transactionsError = true;
        this.transactionsLoading = false;
        this.cdr.markForCheck();
      },
    });
  }

  private applyFilters(): void {
    let result = [...this.allTransactions];

    if (this.viewFilter === 'expense') {
      result = result.filter(t => t.type === 'expense');
    } else if (this.viewFilter === 'income') {
      result = result.filter(t => t.type === 'income');
    }

    if (this.filterMinAmount != null) {
      result = result.filter(t => t.amount >= this.filterMinAmount!);
    }
    if (this.filterMaxAmount != null) {
      result = result.filter(t => t.amount <= this.filterMaxAmount!);
    }

    this.displayedTransactions = result;
  }

  // ── Event handlers ──────────────────────────────────────────────────────────

  onCategorySelected(categoryId: number | null): void {
    this.selectedCategoryId = categoryId;
    this.loadTransactions();
    if (categoryId !== null) {
      this.openAddModal('expense');
    }
  }

  onViewChanged(config: TimelineViewConfig): void {
    this.viewConfig = config;
    this.loadTransactions();
  }

  onTransactionEdit(item: TransactionItem): void {
    this.editingId = item.id;
    this.modalType = item.type as ModalType;
    this.modalMode = 'edit';
    this.modalError = null;
    this.form = {
      amount: item.amount,
      categoryId: item.category?.id ?? null,
      dateTime: toLocalDateTimeInput(new Date(item.dateTime)),
      paymentMethod: item.paymentMethod,
      description: item.description ?? '',
      note: item.note ?? '',
    };
    this.modalOpen = true;
    this.cdr.markForCheck();
  }

  onTransactionDelete(item: TransactionItem): void {
    if (!confirm(`Delete this ${item.type}?`)) return;
    const del$ = item.type === 'expense'
      ? this.transactionService.deleteExpense(item.id)
      : this.transactionService.deleteIncome(item.id);
    del$.subscribe({
      next: () => { this.loadTransactions(); this.loadCategories(); },
      error: () => alert(`Failed to delete ${item.type}. Please try again.`),
    });
  }

  // ── Filter panel ────────────────────────────────────────────────────────────

  toggleFilterPanel(): void {
    this.filterPanelOpen = !this.filterPanelOpen;
    this.cdr.markForCheck();
  }

  setViewFilter(f: ViewFilter): void {
    this.viewFilter = f;
    this.applyFilters();
    this.cdr.markForCheck();
  }

  applyFilterPanel(): void {
    this.applyFilters();
    this.filterPanelOpen = false;
    this.cdr.markForCheck();
  }

  resetFilters(): void {
    this.viewFilter = 'all';
    this.filterMinAmount = null;
    this.filterMaxAmount = null;
    this.applyFilters();
    this.filterPanelOpen = false;
    this.cdr.markForCheck();
  }

  // ── Modal controls ──────────────────────────────────────────────────────────

  openAddModal(type: ModalType): void {
    this.modalType = type;
    this.modalMode = 'add';
    this.editingId = null;
    this.modalError = null;
    this.form = {
      amount: null,
      categoryId: this.selectedCategoryId,
      dateTime: toLocalDateTimeInput(new Date()),
      paymentMethod: 'credit_card',
      description: '',
      note: '',
    };
    this.modalOpen = true;
    this.cdr.markForCheck();
  }

  closeModal(): void {
    this.modalOpen = false;
    this.modalError = null;
    this.cdr.markForCheck();
  }

  selectCategory(id: number): void {
    this.form.categoryId = id;
  }

  selectPayment(key: string): void {
    this.form.paymentMethod = key;
  }

  saveTransaction(): void {
    if (!this.form.amount || this.form.amount <= 0) {
      this.modalError = 'Please enter a valid amount.';
      return;
    }
    if (!this.form.categoryId) {
      this.modalError = 'Please select a category.';
      return;
    }
    if (!this.form.dateTime) {
      this.modalError = 'Please enter a date and time.';
      return;
    }
    if (this.householdId == null) return;

    this.modalSaving = true;
    this.modalError = null;
    this.cdr.markForCheck();

    const isoDateTime = new Date(this.form.dateTime).toISOString();

    if (this.modalType === 'expense') {
      if (this.modalMode === 'add') {
        this.transactionService.createExpense({
          amount: this.form.amount,
          dateTime: isoDateTime,
          description: this.form.description || undefined,
          note: this.form.note || undefined,
          paymentMethod: this.form.paymentMethod,
          expenseCategoryId: this.form.categoryId,
          householdId: this.householdId,
        }).subscribe({
          next: () => { this.modalSaving = false; this.modalOpen = false; this.loadTransactions(); this.loadCategories(); },
          error: () => { this.modalSaving = false; this.modalError = 'Failed to save expense.'; this.cdr.markForCheck(); },
        });
      } else {
        if (this.editingId == null) return;
        this.transactionService.updateExpense(this.editingId, {
          amount: this.form.amount,
          dateTime: isoDateTime,
          description: this.form.description,
          note: this.form.note,
          paymentMethod: this.form.paymentMethod,
          expenseCategoryId: this.form.categoryId,
        }).subscribe({
          next: () => { this.modalSaving = false; this.modalOpen = false; this.loadTransactions(); this.loadCategories(); },
          error: () => { this.modalSaving = false; this.modalError = 'Failed to update expense.'; this.cdr.markForCheck(); },
        });
      }
    } else {
      if (this.modalMode === 'add') {
        this.transactionService.createIncome({
          amount: this.form.amount,
          dateTime: isoDateTime,
          description: this.form.description || undefined,
          note: this.form.note || undefined,
          paymentMethod: this.form.paymentMethod,
          incomeCategoryId: this.form.categoryId,
          householdId: this.householdId,
        }).subscribe({
          next: () => { this.modalSaving = false; this.modalOpen = false; this.loadTransactions(); this.loadCategories(); },
          error: () => { this.modalSaving = false; this.modalError = 'Failed to save income.'; this.cdr.markForCheck(); },
        });
      } else {
        if (this.editingId == null) return;
        this.transactionService.updateIncome(this.editingId, {
          amount: this.form.amount,
          dateTime: isoDateTime,
          description: this.form.description,
          note: this.form.note,
          paymentMethod: this.form.paymentMethod,
          incomeCategoryId: this.form.categoryId,
        }).subscribe({
          next: () => { this.modalSaving = false; this.modalOpen = false; this.loadTransactions(); this.loadCategories(); },
          error: () => { this.modalSaving = false; this.modalError = 'Failed to update income.'; this.cdr.markForCheck(); },
        });
      }
    }
  }

  // ── Template helpers ────────────────────────────────────────────────────────

  get activeCategoriesForModal(): Category[] {
    return this.modalType === 'expense' ? this.expenseCategories : this.incomeCategories;
  }

  get sidebarCategories(): Category[] {
    return this.viewFilter === 'income' ? this.incomeCategories : this.expenseCategories;
  }

  get sidebarFavorites(): Category[] {
    return this.viewFilter === 'income' ? this.incomeFavorites : this.expenseFavorites;
  }

  get sidebarType(): 'expense' | 'income' {
    return this.viewFilter === 'income' ? 'income' : 'expense';
  }

  getCategoryDisplayName(cat: Category): string {
    if (this.languageService.currentLang === 'he' && cat.nameHe) return cat.nameHe;
    return cat.name;
  }

  getBgColor(color: string): string {
    return color + '33';
  }

  get hasActiveFilters(): boolean {
    return this.viewFilter !== 'all' || this.filterMinAmount != null || this.filterMaxAmount != null;
  }
}
