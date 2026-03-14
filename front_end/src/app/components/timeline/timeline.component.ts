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
import {
  getFinancialPeriod,
  getFinancialWeeks,
  FinancialWeek,
  FinancialPeriod,
  buildWeekLabel,
  buildDayLabel,
  buildHourLabel,
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
  paymentMethod: 'credit_card' | 'debit_card' | 'cash' | 'bank_transfer';
  category: {
    id: number;
    name: string;
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
  view: 'hourly' | 'daily' | 'weekly' | 'monthly';
  periodOffset: number;
  weekNumber?: number;
  date?: string;
}

// ─── Internal grouping types ──────────────────────────────────────────────────

interface HourGroup {
  label: string;
  hour: number;
  total: number;
  transactions: TransactionItem[];
}

interface DayGroup {
  label: string;
  dateKey: string;
  total: number;
  transactions: TransactionItem[];
  hourGroups?: HourGroup[];
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
  imports: [CommonModule],
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
  currentView: 'hourly' | 'daily' | 'weekly' | 'monthly' = 'monthly';
  periodOffset = 0;
  activeWeekNumber = 1;
  activeDate: Date = new Date();
  activeHour = 9;

  // ── Derived display data ────────────────────────────────────────────────────
  period!: FinancialPeriod;
  weeks!: FinancialWeek[];
  periodLabel  = '';
  navLabel     = '';
  grandTotal   = 0;

  // Grouped data per view
  weekGroups:  WeekGroup[]  = [];
  dayGroups:   DayGroup[]   = [];
  hourGroups:  HourGroup[]  = [];
  hourTransactions: TransactionItem[] = [];

  // Action menu
  openMenuId: number | null = null;

  readonly views: Array<{ key: 'monthly' | 'weekly' | 'daily' | 'hourly'; label: string }> = [
    { key: 'monthly', label: 'Monthly' },
    { key: 'weekly',  label: 'Weekly'  },
    { key: 'daily',   label: 'Daily'   },
    { key: 'hourly',  label: 'Hourly'  },
  ];

  constructor() {
    this.rebuild();
  }

  ngOnChanges(changes: SimpleChanges): void {
    if (changes['transactions'] || changes['type'] || changes['loading']) {
      this.rebuild();
    }
  }

  // ── Navigation ──────────────────────────────────────────────────────────────

  selectView(view: 'hourly' | 'daily' | 'weekly' | 'monthly'): void {
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
      this.periodOffset -= 1;
      this.rebuild();
      this.emitViewChanged();
    } else if (this.currentView === 'daily') {
      this.stepDay(-1);
    } else if (this.currentView === 'hourly') {
      this.stepHour(-1);
    }
  }

  next(): void {
    if (this.currentView === 'monthly') {
      this.periodOffset += 1;
      this.rebuild();
      this.emitViewChanged();
    } else if (this.currentView === 'weekly') {
      this.periodOffset += 1;
      this.rebuild();
      this.emitViewChanged();
    } else if (this.currentView === 'daily') {
      this.stepDay(1);
    } else if (this.currentView === 'hourly') {
      this.stepHour(1);
    }
  }

  selectWeek(week: FinancialWeek): void {
    if (!week.start) return;
    this.activeWeekNumber = week.weekNumber;
    this.activeDate = new Date(week.start);
    this.currentView = 'daily';
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

  private stepHour(delta: number): void {
    this.activeHour = (this.activeHour + delta + 24) % 24;
    this.rebuild();
    this.emitViewChanged();
  }

  // ── Rebuild grouped data ────────────────────────────────────────────────────

  private rebuild(): void {
    this.period = getFinancialPeriod(this.periodOffset);
    this.weeks  = getFinancialWeeks(this.period);
    this.grandTotal = sumAmounts(this.transactions);

    switch (this.currentView) {
      case 'monthly': this.buildMonthly();  break;
      case 'weekly':  this.buildWeekly();   break;
      case 'daily':   this.buildDaily();    break;
      case 'hourly':  this.buildHourly();   break;
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

  // Weekly: group by day
  private buildWeekly(): void {
    const activeWeek = this.weeks.find(w => w.weekNumber === this.activeWeekNumber)
      ?? this.weeks[0];

    if (!activeWeek.start || !activeWeek.end) {
      this.dayGroups = [];
      return;
    }

    this.dayGroups = this.groupByDay(this.transactions);
  }

  // Daily: group by hour
  private buildDaily(): void {
    this.dayGroups = this.groupByHour(this.transactions, this.activeDate);
  }

  // Hourly: flat list for active hour
  private buildHourly(): void {
    this.hourTransactions = this.transactions.filter(t => {
      const d = new Date(t.dateTime);
      return d.getHours() === this.activeHour &&
             this.sameLocalDate(d, this.activeDate);
    });
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

  private groupByHour(txList: TransactionItem[], forDate: Date): DayGroup[] {
    const dayDate = new Date(forDate.getFullYear(), forDate.getMonth(), forDate.getDate());
    const dayTx   = txList.filter(t => this.sameLocalDate(new Date(t.dateTime), forDate));

    const map = new Map<number, TransactionItem[]>();
    for (const tx of dayTx) {
      const h = new Date(tx.dateTime).getHours();
      if (!map.has(h)) map.set(h, []);
      map.get(h)!.push(tx);
    }

    const sortedHours = Array.from(map.keys()).sort((a, b) => a - b);
    const hourGroupsArr: HourGroup[] = sortedHours.map(h => {
      const txs   = map.get(h)!;
      const hh    = String(h).padStart(2, '0');
      const total = sumAmounts(txs);
      return {
        label: `${hh}:00 · ${formatNIS(total)}`,
        hour: h,
        total,
        transactions: txs,
      };
    });

    const dayTotal = sumAmounts(dayTx);
    return [{
      label: `${buildDayLabel(dayDate)} · ${formatNIS(dayTotal)}`,
      dateKey: `${dayDate.getFullYear()}-${dayDate.getMonth()}-${dayDate.getDate()}`,
      total: dayTotal,
      transactions: dayTx,
      hourGroups: hourGroupsArr,
      collapsed: false,
    }];
  }

  private sameLocalDate(a: Date, b: Date): boolean {
    return a.getFullYear() === b.getFullYear() &&
           a.getMonth()    === b.getMonth()    &&
           a.getDate()     === b.getDate();
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

      case 'hourly':
        return buildHourLabel(this.activeDate, this.activeHour);
    }
  }

  // ── Emit ────────────────────────────────────────────────────────────────────

  private emitViewChanged(): void {
    const config: TimelineViewConfig = {
      view:         this.currentView,
      periodOffset: this.periodOffset,
    };

    if (this.currentView === 'daily' || this.currentView === 'hourly') {
      config.weekNumber = this.activeWeekNumber;
    }

    if (this.currentView === 'hourly') {
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
    this.transactionDelete.emit(tx);
  }

  // ── Template helpers ────────────────────────────────────────────────────────

  formatNIS(amount: number): string {
    return formatNIS(amount);
  }

  formatPayment(method: string): string {
    return formatPaymentMethod(method);
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

  trackByHour(_: number, item: HourGroup): number {
    return item.hour;
  }

  trackByWeek(_: number, week: FinancialWeek): number {
    return week.weekNumber;
  }
}
