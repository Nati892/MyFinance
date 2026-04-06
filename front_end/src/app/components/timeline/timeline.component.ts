import {
  Component,
  Input,
  Output,
  EventEmitter,
  OnChanges,
  SimpleChanges,
  ChangeDetectionStrategy,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { TranslateModule } from '@ngx-translate/core';
import { LanguageService } from '../../services/language.service';
import {
  getFinancialPeriod,
  getFinancialWeeks,
  FinancialWeek,
  FinancialPeriod,
  buildWeekLabel,
  buildDayLabel,
  formatNIS,
  formatPaymentMethod,
  sumAmounts,
} from '../../utils/financial-calendar';

// ─── Public interfaces ────────────────────────────────────────────────────────

export interface TransactionItem {
  id: number;
  amount: number;
  dateTime: string;
  description: string | null;
  note: string | null;
  paymentMethod: 'card' | 'cash' | 'bank_transfer' | 'credit_card' | 'debit_card';
  card?: { id: number; lastFourDigits: string; nickname?: string | null; bankName?: string | null; cardType?: string | null } | null;
  category: {
    id: number;
    name: string;
    nameHe?: string | null;
    icon: string;
    color: string;
  };
  appUser: {
    id: number;
    username: string;
  };
  type: 'expense' | 'income';
}

export interface TimelineViewConfig {
  view: 'daily' | 'weekly' | 'monthly';
  periodOffset: number;
  weekNumber?: number;
  date?: string;
}

// ─── Internal grouping types ──────────────────────────────────────────────────

interface DayGroup {
  label: string;
  dateKey: string;
  total: number;
  transactions: TransactionItem[];
  collapsed: boolean;
}

interface WeekGroup {
  weekNumber: number;
  label: string;
  total: number;
  dayGroups: DayGroup[];
  collapsed: boolean;
}

// ─── Component ────────────────────────────────────────────────────────────────

@Component({
  selector: 'app-timeline',
  standalone: true,
  imports: [CommonModule, TranslateModule],
  templateUrl: './timeline.component.html',
  styleUrls: ['./timeline.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class TimelineComponent implements OnChanges {
  @Input() transactions: TransactionItem[] = [];
  @Input() type: 'expense' | 'income' = 'expense';
  @Input() loading = false;

  @Output() viewChanged      = new EventEmitter<TimelineViewConfig>();
  @Output() transactionEdit  = new EventEmitter<TransactionItem>();
  @Output() transactionDelete = new EventEmitter<TransactionItem>();

  // ── View state ──────────────────────────────────────────────────────────────
  currentView: 'daily' | 'weekly' | 'monthly' = 'monthly';
  periodOffset = 0;
  activeWeekNumber = 1;
  activeDate: Date = new Date();

  // ── Derived display data ────────────────────────────────────────────────────
  period!: FinancialPeriod;
  weeks!: FinancialWeek[];
  periodLabel  = '';
  navLabel     = '';
  grandTotal   = 0;

  // Grouped data per view
  weekGroups:  WeekGroup[]  = [];
  dayGroups:   DayGroup[]   = [];
  // Daily view: flat transaction list for the active day
  dailyTransactions: TransactionItem[] = [];

  // Action menu
  openMenuId: number | null = null;

  readonly views: Array<{ key: 'monthly' | 'weekly' | 'daily'; labelKey: string }> = [
    { key: 'monthly', labelKey: 'TIMELINE.MONTHLY' },
    { key: 'weekly',  labelKey: 'TIMELINE.WEEKLY'  },
    { key: 'daily',   labelKey: 'TIMELINE.DAILY'   },
  ];

  pendingDeleteTx: TransactionItem | null = null;

  constructor(private languageService: LanguageService) {
    this.rebuild();
  }

  getCategoryDisplayName(tx: TransactionItem): string {
    if (this.languageService.currentLang === 'he' && tx.category.nameHe) return tx.category.nameHe;
    return tx.category.name;
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['transactions'] || changes['type'] || changes['loading']) {
      this.rebuild();
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  selectView(view: 'daily' | 'weekly' | 'monthly'): void {
    if (view === 'daily') {
      // Always reset to today when entering daily view so the displayed date
      // matches what the backend fetches.
      this.activeDate = new Date();
    }
    this.currentView = view;
    this.rebuild();
    this.emitViewChanged();
  }

  prev(): void {
    if (this.currentView === 'monthly') {
      this.periodOffset -= 1;
      this.rebuild();
      this.emitViewChanged();
    } else if (this.currentView === 'weekly') {
      this.stepWeek(-1);
    } else if (this.currentView === 'daily') {
      this.stepDay(-1);
    }
  }

  next(): void {
    if (this.currentView === 'monthly') {
      this.periodOffset += 1;
      this.rebuild();
      this.emitViewChanged();
    } else if (this.currentView === 'weekly') {
      this.stepWeek(1);
    } else if (this.currentView === 'daily') {
      this.stepDay(1);
    }
  }

  selectWeek(week: FinancialWeek): void {
    if (!week.start) return;
    this.activeWeekNumber = week.weekNumber;
    this.activeDate = new Date(week.start);
    // In weekly view: stay in weekly, just change the active week.
    // In daily: drill down into that week's daily view.
    if (this.currentView !== 'weekly') {
      this.currentView = 'daily';
    }
    this.rebuild();
    this.emitViewChanged();
  }

  private stepWeek(delta: number): void {
    const validWeeks = this.weeks.filter(w => !!w.start && !!w.end);
    const maxWeekNum = validWeeks.length > 0 ? validWeeks[validWeeks.length - 1].weekNumber : 1;
    const next = this.activeWeekNumber + delta;

    if (next < 1) {
      this.periodOffset -= 1;
      const newWeeks = getFinancialWeeks(getFinancialPeriod(this.periodOffset));
      const newValid = newWeeks.filter(w => !!w.start && !!w.end);
      this.activeWeekNumber = newValid.length > 0 ? newValid[newValid.length - 1].weekNumber : 1;
    } else if (next > maxWeekNum) {
      this.periodOffset += 1;
      this.activeWeekNumber = 1;
    } else {
      this.activeWeekNumber = next;
    }

    this.rebuild();
    this.emitViewChanged();
  }

  private stepDay(delta: number): void {
    const d = new Date(this.activeDate);
    d.setDate(d.getDate() + delta);
    this.activeDate = d;
    this.rebuild();
    this.emitViewChanged();
  }

  // ── Rebuild grouped data ────────────────────────────────────────────────────

  private rebuild(): void {
    this.period = getFinancialPeriod(this.periodOffset);
    this.weeks  = getFinancialWeeks(this.period);
    this.grandTotal = sumAmounts(this.transactions);

    switch (this.currentView) {
      case 'monthly': this.buildMonthly(); break;
      case 'weekly':  this.buildWeekly();  break;
      case 'daily':   this.buildDaily();   break;
    }

    this.navLabel = this.buildNavLabel();
  }

  // Monthly: group by week → day
  private buildMonthly(): void {
    this.weekGroups = this.weeks.map(week => {
      if (!week.start || !week.end) {
        return {
          weekNumber: week.weekNumber,
          label: `Week ${week.weekNumber}`,
          total: 0,
          dayGroups: [],
          collapsed: true,
        };
      }

      const weekTx = this.transactions.filter(t => {
        const d = new Date(t.dateTime);
        return week.start && week.end && d >= week.start && d <= week.end;
      });

      const dayGroups = this.groupByDay(weekTx);
      const wLabel = `Week ${week.weekNumber} · ${week.label}`;

      return {
        weekNumber: week.weekNumber,
        label: `${wLabel} · ${formatNIS(sumAmounts(weekTx))}`,
        total: sumAmounts(weekTx),
        dayGroups,
        collapsed: false,
      };
    });
  }

  // Weekly: group by day (filtered to the active week)
  private buildWeekly(): void {
    let activeWeek = this.weeks.find(w => w.weekNumber === this.activeWeekNumber)
      ?? this.weeks[0];

    // If the stored week has no dates (e.g. navigated to a shorter period), fall back
    // to the first valid week rather than showing an empty state.
    if (!activeWeek.start || !activeWeek.end) {
      activeWeek = this.weeks.find(w => !!w.start && !!w.end) ?? activeWeek;
      this.activeWeekNumber = activeWeek.weekNumber;
    }

    if (!activeWeek.start || !activeWeek.end) {
      this.dayGroups = [];
      return;
    }

    const weekStart = activeWeek.start;
    const weekEnd   = activeWeek.end;
    const weekTx = this.transactions.filter(t => {
      const d = new Date(t.dateTime);
      return d >= weekStart && d <= weekEnd;
    });
    this.dayGroups = this.groupByDay(weekTx);
  }

  // Daily: flat list for the active day (transactions are already pre-filtered by
  // the backend to that specific day via the `date` param).
  private buildDaily(): void {
    // The backend scopes the response to the requested date, so `this.transactions`
    // already contains only that day's transactions. Display them as a flat list.
    this.dailyTransactions = [...this.transactions].sort(
      (a, b) => new Date(a.dateTime).getTime() - new Date(b.dateTime).getTime()
    );
  }

  // ── Grouping helpers ────────────────────────────────────────────────────────

  private groupByDay(txList: TransactionItem[]): DayGroup[] {
    const map = new Map<string, TransactionItem[]>();

    for (const tx of txList) {
      const d = new Date(tx.dateTime);
      const key = `${d.getFullYear()}-${d.getMonth()}-${d.getDate()}`;
      if (!map.has(key)) map.set(key, []);
      map.get(key)!.push(tx);
    }

    // Sort keys chronologically
    const sortedKeys = Array.from(map.keys()).sort((a, b) => {
      const [ay, am, ad] = a.split('-').map(Number);
      const [by, bm, bd] = b.split('-').map(Number);
      return new Date(ay, am, ad).getTime() - new Date(by, bm, bd).getTime();
    });

    return sortedKeys.map(key => {
      const txs   = map.get(key)!;
      const first = new Date(txs[0].dateTime);
      const dayDate = new Date(first.getFullYear(), first.getMonth(), first.getDate());
      const total = sumAmounts(txs);
      return {
        label: `${buildDayLabel(dayDate)} · ${formatNIS(total)}`,
        dateKey: key,
        total,
        transactions: txs,
        collapsed: false,
      };
    });
  }

  sameLocalDate(a: Date, b: Date): boolean {
    return a.getFullYear() === b.getFullYear() &&
           a.getMonth()    === b.getMonth()    &&
           a.getDate()     === b.getDate();
  }

  get periodDays(): Date[] {
    if (!this.period?.start || !this.period?.end) return [];
    const days: Date[] = [];
    const cur = new Date(this.period.start);
    cur.setHours(0, 0, 0, 0);
    const end = new Date(this.period.end);
    end.setHours(0, 0, 0, 0);
    while (cur <= end) {
      days.push(new Date(cur));
      cur.setDate(cur.getDate() + 1);
    }
    return days;
  }

  selectDay(date: Date): void {
    this.activeDate = date;
    this.rebuild();
    this.emitViewChanged();
  }

  trackByDate(_: number, d: Date): number {
    return d.getTime();
  }

  // ── Nav label ───────────────────────────────────────────────────────────────

  private buildNavLabel(): string {
    switch (this.currentView) {
      case 'monthly':
        return this.period.label;

      case 'weekly': {
        const w = this.weeks.find(x => x.weekNumber === this.activeWeekNumber) ?? this.weeks[0];
        return buildWeekLabel(w);
      }

      case 'daily':
        return buildDayLabel(this.activeDate);
    }
  }

  // ── Emit ────────────────────────────────────────────────────────────────────

  private emitViewChanged(): void {
    const config: TimelineViewConfig = {
      view:         this.currentView,
      periodOffset: this.periodOffset,
    };

    if (this.currentView === 'weekly') {
      config.weekNumber = this.activeWeekNumber;
    }

    if (this.currentView === 'daily') {
      // Send the ISO date so the backend can scope the query to this specific day.
      config.date = this.activeDate.toISOString();
    }

    this.viewChanged.emit(config);
  }

  // ── Toggle collapse ─────────────────────────────────────────────────────────

  toggleWeek(wg: WeekGroup): void {
    wg.collapsed = !wg.collapsed;
  }

  toggleDay(dg: DayGroup): void {
    dg.collapsed = !dg.collapsed;
  }

  // ── Action menu ─────────────────────────────────────────────────────────────

  toggleMenu(tx: TransactionItem, event: Event): void {
    event.stopPropagation();
    this.openMenuId = this.openMenuId === tx.id ? null : tx.id;
  }

  closeMenu(): void {
    this.openMenuId = null;
  }

  onEdit(tx: TransactionItem): void {
    this.openMenuId = null;
    this.transactionEdit.emit(tx);
  }

  onDelete(tx: TransactionItem): void {
    this.openMenuId = null;
    this.pendingDeleteTx = tx;
  }

  confirmDeleteTx(): void {
    if (this.pendingDeleteTx) {
      this.transactionDelete.emit(this.pendingDeleteTx);
      this.pendingDeleteTx = null;
    }
  }

  cancelDeleteTx(): void {
    this.pendingDeleteTx = null;
  }

  // ── Template helpers ────────────────────────────────────────────────────────

  formatNIS(amount: number): string {
    return formatNIS(amount);
  }

  formatPayment(tx: TransactionItem): string {
    return formatPaymentMethod(tx.paymentMethod, tx.card);
  }

  getPaymentIcon(method: string): string {
    switch (method) {
      case 'credit_card':   return 'credit_card';
      case 'debit_card':    return 'payment';
      case 'cash':          return 'payments';
      case 'bank_transfer': return 'account_balance';
      default:              return 'attach_money';
    }
  }

  getBgColor(color: string): string {
    return color + '33';
  }

  skeletonItems = [1, 2, 3, 4];

  trackById(_: number, item: TransactionItem): number {
    return item.id;
  }

  trackByKey(_: number, item: DayGroup | WeekGroup): string {
    return 'weekNumber' in item ? String((item as WeekGroup).weekNumber) : (item as DayGroup).dateKey;
  }

  trackByWeek(_: number, week: FinancialWeek): number {
    return week.weekNumber;
  }
}
