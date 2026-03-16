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

import { TranslateModule } from '@ngx-translate/core';

import { BudgetService, MonthBudgetRow, WeekSpend, MonthSpend } from '../../services/budget.service';
import { HouseholdStateService } from '../../services/household-state.service';
import { LanguageService } from '../../services/language.service';

const MONTH_NAMES = [
  'January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December',
];

export interface ChartBar {
  label: string;
  value: number;
}

@Component({
  selector: 'app-app-budget',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule],
  templateUrl: './app-budget.component.html',
  styleUrls: ['./app-budget.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class AppBudgetComponent implements OnInit, OnDestroy {
  // ── Household ───────────────────────────────────────────────────────────────
  householdId: number | null = null;
  noHousehold = false;

  // ── View state ──────────────────────────────────────────────────────────────
  viewMode: 'table' | 'graph' = 'table';
  graphMode: 'week' | 'month' = 'week';

  // ── Month navigation ────────────────────────────────────────────────────────
  currentYear: number;
  currentMonth: number; // 1-12

  private readonly today = new Date();

  // ── Table data ──────────────────────────────────────────────────────────────
  budgetRows: MonthBudgetRow[] = [];
  loading = false;

  // ── Inline edit ─────────────────────────────────────────────────────────────
  editingBudgetCategoryId: number | null = null;
  editingBudgetValue: number | null = null;
  editingBudgetMode: 'base' | 'month' = 'base';

  // ── Graph data ──────────────────────────────────────────────────────────────
  selectedCategoryId: number | null = null;
  weekData: WeekSpend[] = [];
  monthData: MonthSpend[] = [];
  graphLoading = false;

  // ── Subscriptions ───────────────────────────────────────────────────────────
  private subs = new Subscription();

  constructor(
    private budgetService: BudgetService,
    private householdState: HouseholdStateService,
    private cdr: ChangeDetectorRef,
    private languageService: LanguageService,
  ) {
    this.currentYear = this.today.getFullYear();
    this.currentMonth = this.today.getMonth() + 1;
  }

  ngOnInit(): void {
    const household = this.householdState.getSelectedHousehold();
    if (!household) {
      this.noHousehold = true;
      this.cdr.markForCheck();
      return;
    }
    this.householdId = household.householdId;
    this.loadMonthBudget();

    this.subs.add(
      this.householdState.selectedHousehold$.subscribe(h => {
        if (h && h.householdId !== this.householdId) {
          this.householdId = h.householdId;
          this.noHousehold = false;
          this.loadMonthBudget();
          this.cdr.markForCheck();
        }
      })
    );
  }

  ngOnDestroy(): void {
    this.subs.unsubscribe();
  }

  // ── Month nav ───────────────────────────────────────────────────────────────

  get monthLabel(): string {
    return `${MONTH_NAMES[this.currentMonth - 1]} ${this.currentYear}`;
  }

  get isCurrentMonth(): boolean {
    return (
      this.currentYear === this.today.getFullYear() &&
      this.currentMonth === this.today.getMonth() + 1
    );
  }

  prevMonth(): void {
    if (this.currentMonth === 1) {
      this.currentMonth = 12;
      this.currentYear--;
    } else {
      this.currentMonth--;
    }
    this.loadMonthBudget();
    if (this.viewMode === 'graph') {
      this.loadGraphData();
    }
  }

  nextMonth(): void {
    if (this.isCurrentMonth) return;
    if (this.currentMonth === 12) {
      this.currentMonth = 1;
      this.currentYear++;
    } else {
      this.currentMonth++;
    }
    this.loadMonthBudget();
    if (this.viewMode === 'graph') {
      this.loadGraphData();
    }
  }

  // ── Data loading ────────────────────────────────────────────────────────────

  loadMonthBudget(): void {
    if (this.householdId == null) return;
    this.loading = true;
    this.cdr.markForCheck();

    this.budgetService
      .getMonthBudget(this.householdId, this.currentYear, this.currentMonth)
      .subscribe({
        next: rows => {
          this.budgetRows = rows ?? [];
          this.loading = false;
          this.cdr.markForCheck();
        },
        error: () => {
          this.loading = false;
          this.cdr.markForCheck();
        },
      });
  }

  saveBudget(categoryId: number, amount: number): void {
    if (this.householdId == null) return;
    this.budgetService
      .overrideBudget(categoryId, this.householdId, this.currentYear, this.currentMonth, amount)
      .subscribe({
        next: () => {
          this.editingBudgetCategoryId = null;
          this.editingBudgetValue = null;
          this.loadMonthBudget();
        },
        error: () => {
          this.editingBudgetCategoryId = null;
          this.editingBudgetValue = null;
          this.cdr.markForCheck();
        },
      });
  }

  loadWeekGraph(): void {
    if (this.householdId == null) return;
    this.graphLoading = true;
    this.cdr.markForCheck();

    this.budgetService
      .getByWeek(this.householdId, this.currentYear, this.currentMonth, this.selectedCategoryId)
      .subscribe({
        next: data => {
          this.weekData = data ?? [];
          this.graphLoading = false;
          this.cdr.markForCheck();
        },
        error: () => {
          this.graphLoading = false;
          this.cdr.markForCheck();
        },
      });
  }

  loadMonthGraph(): void {
    if (this.householdId == null) return;
    this.graphLoading = true;
    this.cdr.markForCheck();

    let startMonth = this.currentMonth - 5;
    let startYear = this.currentYear;
    if (startMonth < 1) {
      startMonth += 12;
      startYear--;
    }

    this.budgetService
      .getByMonth(
        this.householdId,
        this.currentYear,
        startMonth,
        this.currentMonth,
        this.selectedCategoryId
      )
      .subscribe({
        next: data => {
          this.monthData = data ?? [];
          this.graphLoading = false;
          this.cdr.markForCheck();
        },
        error: () => {
          this.graphLoading = false;
          this.cdr.markForCheck();
        },
      });
  }

  loadGraphData(): void {
    if (this.graphMode === 'week') {
      this.loadWeekGraph();
    } else {
      this.loadMonthGraph();
    }
  }

  // ── View mode switching ─────────────────────────────────────────────────────

  setViewMode(mode: 'table' | 'graph'): void {
    this.viewMode = mode;
    if (mode === 'graph') {
      this.loadGraphData();
    }
    this.cdr.markForCheck();
  }

  setGraphMode(mode: 'week' | 'month'): void {
    this.graphMode = mode;
    this.loadGraphData();
    this.cdr.markForCheck();
  }

  onCategoryChange(): void {
    this.loadGraphData();
  }

  // ── Inline budget editing ───────────────────────────────────────────────────

  startEditBudget(row: MonthBudgetRow, mode: 'base' | 'month' = 'base'): void {
    this.editingBudgetCategoryId = row.id;
    this.editingBudgetMode = mode;
    this.editingBudgetValue = mode === 'month'
      ? (row.override ?? row.baseBudget ?? null)
      : (row.baseBudget ?? null);
    this.cdr.markForCheck();
  }

  setEditMode(mode: 'base' | 'month', row: MonthBudgetRow): void {
    this.editingBudgetMode = mode;
    this.editingBudgetValue = mode === 'month'
      ? (row.override ?? row.baseBudget ?? null)
      : (row.baseBudget ?? null);
    this.cdr.markForCheck();
  }

  commitEditBudget(categoryId: number): void {
    if (this.editingBudgetValue != null && this.editingBudgetValue >= 0) {
      if (this.editingBudgetMode === 'base') {
        this.saveBaseBudget(categoryId, this.editingBudgetValue);
      } else {
        this.saveBudget(categoryId, this.editingBudgetValue);
      }
    } else {
      this.cancelEdit();
    }
  }

  cancelEdit(): void {
    this.editingBudgetCategoryId = null;
    this.editingBudgetValue = null;
    this.cdr.markForCheck();
  }

  onBudgetKeydown(event: KeyboardEvent, categoryId: number): void {
    if (event.key === 'Enter') {
      this.commitEditBudget(categoryId);
    } else if (event.key === 'Escape') {
      this.cancelEdit();
    }
  }

  saveBaseBudget(categoryId: number, amount: number): void {
    if (this.householdId == null) return;
    this.budgetService.setBaseBudget(categoryId, this.householdId, amount).subscribe({
      next: () => {
        this.editingBudgetCategoryId = null;
        this.editingBudgetValue = null;
        this.loadMonthBudget();
      },
      error: () => this.cancelEdit(),
    });
  }

  // ── Chart helpers ───────────────────────────────────────────────────────────

  get weekChartData(): ChartBar[] {
    return this.weekData.map(d => ({ label: d.weekLabel, value: d.total }));
  }

  get monthChartData(): ChartBar[] {
    return this.monthData.map(d => ({ label: d.label, value: d.total }));
  }

  get currentChartData(): ChartBar[] {
    return this.graphMode === 'week' ? this.weekChartData : this.monthChartData;
  }

  getBarColor(): string {
    if (this.selectedCategoryId != null) {
      const row = this.budgetRows.find(r => r.id === this.selectedCategoryId);
      return row?.color ?? '#667eea';
    }
    return '#667eea';
  }

  chartBarX(i: number, n: number): number {
    const slotWidth = 300 / n;
    const barWidth = slotWidth / 1.5;
    const padding = (slotWidth - barWidth) / 2;
    return i * slotWidth + padding;
  }

  chartBarWidth(n: number): number {
    return (300 / n) / 1.5;
  }

  chartBarHeight(value: number, maxVal: number): number {
    return (value / maxVal) * 160;
  }

  chartBarY(value: number, maxVal: number): number {
    return 170 - this.chartBarHeight(value, maxVal);
  }

  chartMaxVal(data: ChartBar[]): number {
    return Math.max(...data.map(d => d.value), 1);
  }

  // ── Template helpers ────────────────────────────────────────────────────────

  getCategoryDisplayName(row: MonthBudgetRow): string {
    if (this.languageService.currentLang === 'he' && row.nameHe) return row.nameHe;
    return row.name;
  }

  getCategoryLetter(name: string): string {
    return name ? name.charAt(0).toUpperCase() : '?';
  }

  isOverBudget(row: MonthBudgetRow): boolean {
    return row.result != null && row.result > 0;
  }

  trackById(_: number, row: MonthBudgetRow): number {
    return row.id;
  }

  get skeletonRows(): number[] {
    return [1, 2, 3, 4, 5];
  }
}
