import { Component, OnInit, OnDestroy, ChangeDetectorRef } from '@angular/core';
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

interface ExpenseForm {
  amount: number | null;
  categoryId: number | null;
  dateTime: string;
  paymentMethod: 'credit_card' | 'debit_card' | 'cash' | 'bank_transfer';
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
  selector: 'app-app-expenses',
  standalone: true,
  imports: [CommonModule, FormsModule, CategorySidebarComponent, TimelineComponent],
  templateUrl: './app-expenses.component.html',
  styleUrls: ['./app-expenses.component.css'],
})
export class AppExpensesComponent implements OnInit, OnDestroy {
  // ── Household ──────────────────────────────────────────────────────────────
  householdId: number | null = null;
  noHousehold = false;

  // ── Categories ─────────────────────────────────────────────────────────────
  categories: Category[] = [];
  favoriteCategories: Category[] = [];
  categoriesError = false;
  selectedCategoryId: number | null = null;

  // ── Transactions ───────────────────────────────────────────────────────────
  transactions: TransactionItem[] = [];
  transactionsLoading = false;
  transactionsError = false;

  // ── View config ────────────────────────────────────────────────────────────
  viewConfig: TimelineViewConfig = {
    view: 'monthly',
    periodOffset: 0,
  };

  // ── Modal ──────────────────────────────────────────────────────────────────
  modalOpen = false;
  modalMode: 'add' | 'edit' = 'add';
  editingExpenseId: number | null = null;
  modalSaving = false;
  modalError: string | null = null;

  form: ExpenseForm = {
    amount: null,
    categoryId: null,
    dateTime: toLocalDateTimeInput(new Date()),
    paymentMethod: 'credit_card',
    description: '',
    note: '',
  };

  readonly paymentMethods: { key: 'credit_card' | 'debit_card' | 'cash' | 'bank_transfer'; label: string; emoji: string }[] = [
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
  ) {}

  ngOnInit(): void {
    const household = this.householdState.getSelectedHousehold();
    if (!household) {
      this.noHousehold = true;
      return;
    }
    this.householdId = household.householdId;
    this.loadCategories();
    this.loadExpenses();

    // React to household changes
    this.subs.add(
      this.householdState.selectedHousehold$.subscribe(h => {
        if (h && h.householdId !== this.householdId) {
          this.householdId = h.householdId;
          this.noHousehold = false;
          this.selectedCategoryId = null;
          this.loadCategories();
          this.loadExpenses();
          this.cdr.markForCheck();
        }
      })
    );
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

  // ── Data loading ───────────────────────────────────────────────────────────

  private loadCategories(): void {
    if (this.householdId == null) return;
    this.categoriesError = false;
    this.categoryService.getExpenseCategories(this.householdId).subscribe({
      next: res => {
        this.categories = res.categories ?? [];
        this.cdr.markForCheck();
      },
      error: () => {
        this.categoriesError = true;
        this.cdr.markForCheck();
      },
    });
    this.categoryService.getExpenseFavorites(this.householdId).subscribe({
      next: res => {
        this.favoriteCategories = res.favorites ?? [];
        this.cdr.markForCheck();
      },
      error: () => {}
    });
  }

  onCreateCategory(data: NewCategoryData): void {
    if (this.householdId == null) return;
    this.categoryService.createExpenseCategory({ ...data, householdId: this.householdId }).subscribe({
      next: () => this.loadCategories(),
      error: () => alert('Failed to create category. Please try again.'),
    });
  }

  loadExpenses(): void {
    if (this.householdId == null) return;
    this.transactionsLoading = true;
    this.transactionsError = false;

    this.transactionService
      .getExpenses({
        householdId: this.householdId,
        view: this.viewConfig.view,
        periodOffset: this.viewConfig.periodOffset,
        weekNumber: this.viewConfig.weekNumber,
        date: this.viewConfig.date,
        categoryId: this.selectedCategoryId,
      })
      .subscribe({
        next: res => {
          this.transactions = (res.expenses ?? []).map((e: any) => ({
            ...e,
            type: 'expense',
            category: e.ExpenseCategory ?? e.expenseCategory,
            appUser:  e.AppUser ?? e.appUser,
          }));
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

  // ── Event handlers ─────────────────────────────────────────────────────────

  onCategorySelected(categoryId: number | null): void {
    this.selectedCategoryId = categoryId;
    this.loadExpenses();
    if (categoryId !== null) {
      this.openAddModal();
    }
  }

  onViewChanged(config: TimelineViewConfig): void {
    this.viewConfig = config;
    this.loadExpenses();
  }

  onTransactionEdit(item: TransactionItem): void {
    this.editingExpenseId = item.id;
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
  }

  onTransactionDelete(item: TransactionItem): void {
    if (!confirm(`Delete "${item.description || 'this expense'}"?`)) return;
    this.transactionService.deleteExpense(item.id).subscribe({
      next: () => {
        this.loadExpenses();
        this.loadCategories();
      },
      error: () => {
        alert('Failed to delete expense. Please try again.');
      },
    });
  }

  // ── Modal controls ─────────────────────────────────────────────────────────

  openAddModal(): void {
    this.modalMode = 'add';
    this.editingExpenseId = null;
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
  }

  closeModal(): void {
    this.modalOpen = false;
    this.modalError = null;
  }

  selectCategory(id: number): void {
    this.form.categoryId = id;
  }

  selectPayment(key: 'credit_card' | 'debit_card' | 'cash' | 'bank_transfer'): void {
    this.form.paymentMethod = key;
  }

  saveExpense(): void {
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

    const isoDateTime = new Date(this.form.dateTime).toISOString();

    if (this.modalMode === 'add') {
      const payload = {
        amount: this.form.amount,
        dateTime: isoDateTime,
        description: this.form.description || undefined,
        note: this.form.note || undefined,
        paymentMethod: this.form.paymentMethod,
        expenseCategoryId: this.form.categoryId,
        householdId: this.householdId,
      };
      this.transactionService.createExpense(payload).subscribe({
        next: () => {
          this.modalSaving = false;
          this.modalOpen = false;
          this.loadExpenses();
          this.loadCategories();
        },
        error: () => {
          this.modalSaving = false;
          this.modalError = 'Failed to save expense. Please try again.';
          this.cdr.markForCheck();
        },
      });
    } else {
      if (this.editingExpenseId == null) return;
      const payload: any = {
        amount: this.form.amount,
        dateTime: isoDateTime,
        description: this.form.description,
        note: this.form.note,
        paymentMethod: this.form.paymentMethod,
        expenseCategoryId: this.form.categoryId,
      };
      this.transactionService.updateExpense(this.editingExpenseId, payload).subscribe({
        next: () => {
          this.modalSaving = false;
          this.modalOpen = false;
          this.loadExpenses();
          this.loadCategories();
        },
        error: () => {
          this.modalSaving = false;
          this.modalError = 'Failed to update expense. Please try again.';
          this.cdr.markForCheck();
        },
      });
    }
  }

  // ── Template helpers ───────────────────────────────────────────────────────

  getCategoryById(id: number | null): Category | undefined {
    if (id == null) return undefined;
    return this.categories.find(c => c.id === id);
  }

  getBgColor(color: string): string {
    return color + '33';
  }
}
