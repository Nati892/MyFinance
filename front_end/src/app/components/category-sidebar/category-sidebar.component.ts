import {
  Component,
  Input,
  Output,
  EventEmitter,
  ChangeDetectionStrategy,
  ChangeDetectorRef,
  OnDestroy,
} from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { TranslateModule } from '@ngx-translate/core';
import { LanguageService } from '../../services/language.service';
import { TranslationApiService } from '../../services/translation-api.service';

export interface Category {
  id: number;
  name: string;
  nameHe?: string;
  icon: string;
  color: string;
  sortOrder: number;
  monthlyBudget?: number | null;
  currentSpend?: number | null;
}

export interface NewCategoryData {
  name: string;
  nameHe: string;
  icon: string;
  color: string;
  monthlyBudget: number | null;
}

// Common Material icons for the picker
const ICON_OPTIONS = [
  'restaurant', 'local_cafe', 'local_bar', 'bakery_dining', 'fastfood',
  'shopping_cart', 'storefront', 'local_grocery_store', 'checkroom', 'devices',
  'directions_car', 'local_gas_station', 'train', 'flight', 'directions_bus',
  'home', 'cottage', 'electrical_services', 'water_drop', 'wifi',
  'sports_soccer', 'sports_basketball', 'fitness_center', 'pool', 'hiking',
  'local_hospital', 'medication', 'spa', 'dentistry', 'health_and_safety',
  'school', 'auto_stories', 'computer', 'headphones', 'movie',
  'pets', 'child_care', 'face', 'cardiology', 'self_improvement',
  'savings', 'account_balance', 'credit_card', 'payments', 'currency_exchange',
  'celebration', 'cake', 'card_giftcard', 'volunteer_activism', 'favorite',
  'work', 'build', 'handyman', 'cleaning_services', 'local_laundry_service',
  'travel_explore', 'beach_access', 'hotel', 'luggage', 'map',
  'label', 'star', 'attach_money', 'receipt', 'wallet',
];

const PRESET_COLORS = [
  '#F44336', '#E91E63', '#9C27B0', '#673AB7', '#3F51B5',
  '#2196F3', '#03A9F4', '#00BCD4', '#009688', '#4CAF50',
  '#8BC34A', '#CDDC39', '#FFC107', '#FF9800', '#FF5722',
  '#795548', '#607D8B', '#667eea',
];

@Component({
  selector: 'app-category-sidebar',
  standalone: true,
  imports: [CommonModule, FormsModule, TranslateModule],
  templateUrl: './category-sidebar.component.html',
  styleUrls: ['./category-sidebar.component.css'],
  changeDetection: ChangeDetectionStrategy.OnPush,
})
export class CategorySidebarComponent implements OnDestroy {
  @Input() categories: Category[] = [];
  @Input() favoriteCategories: Category[] = [];
  @Input() selectedCategoryId: number | null = null;
  @Input() type: 'expense' | 'income' = 'expense';
  @Output() categorySelected = new EventEmitter<number | null>();
  @Output() createCategory = new EventEmitter<NewCategoryData>();

  readonly iconOptions = ICON_OPTIONS;
  readonly presetColors = PRESET_COLORS;

  drawerOpen = false;
  iconSearch = '';
  isTranslatingHe = false;
  isTranslatingEn = false;

  newCategory = {
    name: '',
    nameHe: '',
    icon: 'label',
    color: '#667eea',
    monthlyBudget: null as number | null,
  };

  private enTimer: any = null;
  private heTimer: any = null;

  constructor(
    private cdr: ChangeDetectorRef,
    private languageService: LanguageService,
    private translationApi: TranslationApiService,
  ) {}

  get currentLang() {
    return this.languageService.currentLang;
  }

  get filteredIcons(): string[] {
    if (!this.iconSearch.trim()) return this.iconOptions;
    const q = this.iconSearch.toLowerCase();
    return this.iconOptions.filter(i => i.includes(q));
  }

  getDisplayName(cat: Category): string {
    if (this.languageService.currentLang === 'he' && cat.nameHe) return cat.nameHe;
    return cat.name;
  }

  openDrawer(): void {
    this.newCategory = { name: '', nameHe: '', icon: 'label', color: '#667eea', monthlyBudget: null };
    this.iconSearch = '';
    this.drawerOpen = true;
    this.cdr.markForCheck();
  }

  closeDrawer(): void {
    this.drawerOpen = false;
    this.cdr.markForCheck();
  }

  selectIcon(icon: string): void {
    this.newCategory.icon = icon;
  }

  selectColor(color: string): void {
    this.newCategory.color = color;
  }

  onNameEnChange(): void {
    clearTimeout(this.enTimer);
    if (!this.newCategory.name.trim() || this.newCategory.nameHe.trim()) return;
    this.enTimer = setTimeout(() => this.translateToHe(), 800);
  }

  onNameHeChange(): void {
    clearTimeout(this.heTimer);
    if (!this.newCategory.nameHe.trim() || this.newCategory.name.trim()) return;
    this.heTimer = setTimeout(() => this.translateToEn(), 800);
  }

  translateToHe(): void {
    if (!this.newCategory.name.trim() || this.isTranslatingHe) return;
    this.isTranslatingHe = true;
    this.cdr.markForCheck();
    this.translationApi.translate(this.newCategory.name, 'en', 'he').subscribe(result => {
      if (result) this.newCategory.nameHe = result;
      this.isTranslatingHe = false;
      this.cdr.markForCheck();
    });
  }

  translateToEn(): void {
    if (!this.newCategory.nameHe.trim() || this.isTranslatingEn) return;
    this.isTranslatingEn = true;
    this.cdr.markForCheck();
    this.translationApi.translate(this.newCategory.nameHe, 'he', 'en').subscribe(result => {
      if (result) this.newCategory.name = result;
      this.isTranslatingEn = false;
      this.cdr.markForCheck();
    });
  }

  submitNewCategory(): void {
    const nameEn = this.newCategory.name.trim();
    const nameHe = this.newCategory.nameHe.trim();
    if (!nameEn && !nameHe) return;
    if (!this.newCategory.icon) return;
    this.createCategory.emit({
      name: nameEn || nameHe,
      nameHe: nameHe || nameEn,
      icon: this.newCategory.icon,
      color: this.newCategory.color,
      monthlyBudget: this.type === 'expense' ? (this.newCategory.monthlyBudget || null) : null,
    });
    this.closeDrawer();
  }

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
      return -1;
    }
    return (cat.currentSpend ?? 0) / cat.monthlyBudget;
  }

  getBudgetColor(ratio: number): string {
    if (ratio <= 0.6) return '#4CAF50';
    if (ratio <= 0.85) return '#FF9800';
    return '#F44336';
  }

  getBudgetBorderColor(cat: Category): string {
    const ratio = this.getBudgetRatio(cat);
    if (ratio < 0) return cat.color;
    return this.getBudgetColor(ratio);
  }

  getBudgetBorderWidth(cat: Category): string {
    return this.getBudgetRatio(cat) >= 0 ? '3px' : '2px';
  }

  getBudgetTooltip(cat: Category): string {
    const displayName = this.getDisplayName(cat);
    if (cat.monthlyBudget == null) return displayName;
    return `${displayName}\n\u20AA${cat.currentSpend ?? 0} / \u20AA${cat.monthlyBudget}`;
  }

  getBgColor(color: string): string {
    return color + '33';
  }

  ngOnDestroy(): void {
    clearTimeout(this.enTimer);
    clearTimeout(this.heTimer);
  }
}
