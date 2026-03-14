import {
  Component,
  Input,
  Output,
  EventEmitter,
  ChangeDetectionStrategy,
} from '@angular/core';
import { CommonModule } from '@angular/common';

export interface Category {
  id: number;
  name: string;
  icon: string;
  color: string;
  sortOrder: number;
  monthlyBudget?: number | null;
  currentSpend?: number | null;
}

@Component({
  selector: 'app-category-sidebar',
  standalone: true,
  imports: [CommonModule],
  templateUrl: './category-sidebar.component.html',
  styleUrls: ['./category-sidebar.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CategorySidebarComponent {
  @Input() categories: Category[] = [];
  @Input() selectedCategoryId: number | null = null;
  @Input() type: 'expense' | 'income' = 'expense';
  @Output() categorySelected = new EventEmitter<number | null>();

  readonly CIRCUMFERENCE = 2 * Math.PI * 26; // ≈ 163.36

  selectAll(): void {
    this.categorySelected.emit(null);
  }

  selectCategory(id: number): void {
    this.categorySelected.emit(id);
  }

  getBudgetRatio(cat: Category): number {
    if (
      this.type !== 'expense' ||
      cat.monthlyBudget == null ||
      cat.monthlyBudget <= 0
    ) {
      return -1; // no indicator
    }
    const spend = cat.currentSpend ?? 0;
    return spend / cat.monthlyBudget;
  }

  getBudgetColor(ratio: number): string {
    if (ratio <= 0.6) return '#4CAF50';
    if (ratio <= 0.85) return '#FF9800';
    return '#F44336';
  }

  getDashOffset(ratio: number): number {
    const clamped = Math.min(ratio, 1);
    return this.CIRCUMFERENCE * (1 - clamped);
  }

  getBudgetTooltip(cat: Category): string {
    if (cat.monthlyBudget == null) return '';
    const spend = cat.currentSpend ?? 0;
    return `\u20AA${spend} / \u20AA${cat.monthlyBudget}`;
  }

  /** Hex color + '33' for 20% alpha background */
  getBgColor(color: string): string {
    return color + '33';
  }
}
