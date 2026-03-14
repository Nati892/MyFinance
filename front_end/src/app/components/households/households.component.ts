import { Component, OnInit, OnDestroy, HostListener } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { Subject, takeUntil } from 'rxjs';
import { HouseholdsService } from '../../services/households.service';
import { LoggerService } from '../../services/logger.service';

// ── Interfaces ──────────────────────────────────────────────────────────────

interface Household {
  id: number;
  name: string;
  description: string;
  memberCount?: number;
  members?: HouseholdMember[];
}

interface HouseholdMember {
  appUserId: number;
  username: string;
  role: string;
}

interface AppUser {
  id: number;
  username: string;
  email?: string;
}

interface Category {
  id: number;
  name: string;
  icon: string;
  color: string;
  budget?: number | null;
  sortOrder: number;
}

interface CategoryForm {
  name: string;
  icon: string;
  color: string;
  budget: number | null;
}

// ── Constants ────────────────────────────────────────────────────────────────

export const ICON_LIST = [
  'restaurant', 'local_cafe', 'shopping_cart', 'local_grocery_store',
  'directions_car', 'local_gas_station', 'home', 'electrical_services',
  'water_drop', 'child_care', 'child_friendly', 'school',
  'local_hospital', 'fitness_center', 'sports_soccer', 'movie',
  'music_note', 'flight', 'hotel', 'beach_access',
  'work', 'business_center', 'attach_money', 'savings',
  'account_balance', 'credit_card', 'phone_android', 'computer',
  'wifi', 'pets', 'celebration', 'card_giftcard',
  'local_laundry_service', 'build', 'brush', 'agriculture',
  'local_shipping', 'two_wheeler', 'train', 'subway'
];

export const PRESET_COLORS = [
  '#F44336', '#E91E63', '#9C27B0', '#3F51B5',
  '#2196F3', '#4CAF50', '#FF9800', '#607D8B'
];

@Component({
  selector: 'app-households',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './households.component.html',
  styleUrls: ['./households.component.css']
})
export class HouseholdsComponent implements OnInit, OnDestroy {

  // ── View state ─────────────────────────────────────────────────────────────
  mode: 'list' | 'detail' = 'list';
  currentTab: 'members' | 'expense-cats' | 'income-cats' = 'members';

  // ── List state ─────────────────────────────────────────────────────────────
  households: Household[] = [];
  loading = false;
  error = '';

  // ── New household form ─────────────────────────────────────────────────────
  showNewForm = false;
  newHousehold = { name: '', description: '' };

  // ── Delete confirm ─────────────────────────────────────────────────────────
  confirmDeleteId: number | null = null;

  // ── Detail state ───────────────────────────────────────────────────────────
  selectedHousehold: Household | null = null;
  detailLoading = false;
  detailError = '';

  // ── Inline edit for household name/desc ───────────────────────────────────
  editingHousehold = false;
  editHouseholdForm = { name: '', description: '' };

  // ── Members tab ────────────────────────────────────────────────────────────
  allAppUsers: AppUser[] = [];
  userSearchTerm = '';
  filteredUsers: AppUser[] = [];
  showUserDropdown = false;
  addMemberForm = { appUserId: 0, selectedUsername: '', role: 'member' };
  memberRoleEditing: { [appUserId: number]: string } = {};

  // ── Expense categories tab ─────────────────────────────────────────────────
  expenseCategories: Category[] = [];
  expenseCatsLoading = false;
  showExpenseNewForm = false;
  newExpenseCat: CategoryForm = this.emptyCategory();
  editingExpenseCatId: number | null = null;
  editingExpenseCat: CategoryForm = this.emptyCategory();
  showExpenseIconPicker = false;
  showExpenseEditIconPicker = false;

  // ── Income categories tab ──────────────────────────────────────────────────
  incomeCategories: Category[] = [];
  incomeCatsLoading = false;
  showIncomeNewForm = false;
  newIncomeCat: CategoryForm = this.emptyCategory();
  editingIncomeCatId: number | null = null;
  editingIncomeCat: CategoryForm = this.emptyCategory();
  showIncomeIconPicker = false;
  showIncomeEditIconPicker = false;

  // ── Shared constants exposed to template ──────────────────────────────────
  readonly iconList = ICON_LIST;
  readonly presetColors = PRESET_COLORS;

  private destroy$ = new Subject<void>();

  constructor(
    private householdsService: HouseholdsService,
    private logger: LoggerService
  ) { }

  ngOnInit(): void {
    this.logger.logComponentInit('HouseholdsComponent');
    this.loadHouseholds();
  }

  ngOnDestroy(): void {
    this.logger.logComponentDestroy('HouseholdsComponent');
    this.destroy$.next();
    this.destroy$.complete();
  }

  // ── Close icon pickers when clicking outside ───────────────────────────────
  @HostListener('document:click', ['$event'])
  onDocumentClick(event: MouseEvent): void {
    const target = event.target as HTMLElement;
    if (!target.closest('.icon-picker-wrapper')) {
      this.showExpenseIconPicker = false;
      this.showExpenseEditIconPicker = false;
      this.showIncomeIconPicker = false;
      this.showIncomeEditIconPicker = false;
    }
    if (!target.closest('.user-search-wrapper')) {
      this.showUserDropdown = false;
    }
  }

  // ── Households list ────────────────────────────────────────────────────────

  loadHouseholds(): void {
    this.loading = true;
    this.error = '';
    this.householdsService.getHouseholds().pipe(takeUntil(this.destroy$)).subscribe({
      next: (res) => {
        this.households = Array.isArray(res) ? res : (res.data ?? []);
        this.loading = false;
        this.logger.info('HOUSEHOLDS_LOADED', `Loaded ${this.households.length} households`);
      },
      error: (err) => {
        this.error = 'Failed to load households.';
        this.loading = false;
        this.logger.err('HOUSEHOLDS_LOAD_ERROR', 'Failed to load households', err);
      }
    });
  }

  showCreateForm(): void {
    this.showNewForm = true;
    this.newHousehold = { name: '', description: '' };
  }

  cancelCreate(): void {
    this.showNewForm = false;
  }

  createHousehold(): void {
    if (!this.newHousehold.name.trim()) {
      alert('Household name is required.');
      return;
    }
    this.householdsService.createHousehold(this.newHousehold).subscribe({
      next: () => {
        this.logger.info('HOUSEHOLD_CREATED', `Created household: ${this.newHousehold.name}`);
        this.showNewForm = false;
        this.loadHouseholds();
      },
      error: (err) => {
        this.logger.err('HOUSEHOLD_CREATE_ERROR', 'Failed to create household', err);
        alert(err.error?.error || 'Failed to create household.');
      }
    });
  }

  requestDelete(id: number): void {
    this.confirmDeleteId = id;
  }

  cancelDelete(): void {
    this.confirmDeleteId = null;
  }

  confirmDelete(id: number): void {
    this.householdsService.deleteHousehold(id).subscribe({
      next: () => {
        this.logger.warn('HOUSEHOLD_DELETED', `Deleted household id=${id}`);
        this.confirmDeleteId = null;
        this.loadHouseholds();
      },
      error: (err) => {
        this.logger.err('HOUSEHOLD_DELETE_ERROR', 'Failed to delete household', err);
        alert(err.error?.error || 'Failed to delete household.');
        this.confirmDeleteId = null;
      }
    });
  }

  // ── Household detail ───────────────────────────────────────────────────────

  openDetail(household: Household): void {
    this.mode = 'detail';
    this.currentTab = 'members';
    this.selectedHousehold = household;
    this.editingHousehold = false;
    this.loadDetail(household.id);
  }

  backToList(): void {
    this.mode = 'list';
    this.selectedHousehold = null;
    this.expenseCategories = [];
    this.incomeCategories = [];
    this.closeAllForms();
  }

  loadDetail(id: number): void {
    this.detailLoading = true;
    this.detailError = '';
    this.householdsService.getHousehold(id).pipe(takeUntil(this.destroy$)).subscribe({
      next: (res) => {
        this.selectedHousehold = res.data ?? res;
        this.detailLoading = false;
        this.logger.info('HOUSEHOLD_DETAIL_LOADED', `Loaded detail for household id=${id}`);
      },
      error: (err) => {
        this.detailError = 'Failed to load household details.';
        this.detailLoading = false;
        this.logger.err('HOUSEHOLD_DETAIL_ERROR', 'Failed to load household detail', err);
      }
    });
  }

  switchTab(tab: 'members' | 'expense-cats' | 'income-cats'): void {
    this.currentTab = tab;
    this.closeAllForms();
    if (!this.selectedHousehold) return;
    if (tab === 'expense-cats' && this.expenseCategories.length === 0) {
      this.loadExpenseCategories();
    }
    if (tab === 'income-cats' && this.incomeCategories.length === 0) {
      this.loadIncomeCategories();
    }
  }

  closeAllForms(): void {
    this.showExpenseNewForm = false;
    this.showIncomeNewForm = false;
    this.editingExpenseCatId = null;
    this.editingIncomeCatId = null;
    this.showExpenseIconPicker = false;
    this.showExpenseEditIconPicker = false;
    this.showIncomeIconPicker = false;
    this.showIncomeEditIconPicker = false;
  }

  // ── Inline household edit ──────────────────────────────────────────────────

  startEditHousehold(): void {
    if (!this.selectedHousehold) return;
    this.editHouseholdForm = {
      name: this.selectedHousehold.name,
      description: this.selectedHousehold.description
    };
    this.editingHousehold = true;
  }

  cancelEditHousehold(): void {
    this.editingHousehold = false;
  }

  saveHousehold(): void {
    if (!this.selectedHousehold) return;
    if (!this.editHouseholdForm.name.trim()) {
      alert('Name is required.');
      return;
    }
    this.householdsService.updateHousehold(this.selectedHousehold.id, this.editHouseholdForm).subscribe({
      next: () => {
        this.logger.info('HOUSEHOLD_UPDATED', `Updated household id=${this.selectedHousehold!.id}`);
        this.selectedHousehold!.name = this.editHouseholdForm.name;
        this.selectedHousehold!.description = this.editHouseholdForm.description;
        this.editingHousehold = false;
        // Refresh list in background
        this.loadHouseholds();
      },
      error: (err) => {
        this.logger.err('HOUSEHOLD_UPDATE_ERROR', 'Failed to update household', err);
        alert(err.error?.error || 'Failed to update household.');
      }
    });
  }

  // ── Members ────────────────────────────────────────────────────────────────

  loadAppUsers(): void {
    this.householdsService.getAppUsers().pipe(takeUntil(this.destroy$)).subscribe({
      next: (res) => {
        this.allAppUsers = Array.isArray(res) ? res : (res.data ?? []);
        this.filterUsers();
      },
      error: (err) => {
        this.logger.err('APP_USERS_LOAD_ERROR', 'Failed to load app users', err);
      }
    });
  }

  onUserSearchInput(): void {
    this.filterUsers();
    this.showUserDropdown = true;
  }

  filterUsers(): void {
    const term = this.userSearchTerm.toLowerCase();
    const existingIds = (this.selectedHousehold?.members ?? []).map(m => m.appUserId);
    this.filteredUsers = this.allAppUsers
      .filter(u => !existingIds.includes(u.id))
      .filter(u => !term || u.username.toLowerCase().includes(term) || (u.email ?? '').toLowerCase().includes(term));
  }

  focusUserSearch(): void {
    if (this.allAppUsers.length === 0) {
      this.loadAppUsers();
    } else {
      this.filterUsers();
    }
    this.showUserDropdown = true;
  }

  selectUser(user: AppUser): void {
    this.addMemberForm.appUserId = user.id;
    this.addMemberForm.selectedUsername = user.username;
    this.userSearchTerm = user.username;
    this.showUserDropdown = false;
  }

  addMember(): void {
    if (!this.selectedHousehold || !this.addMemberForm.appUserId) {
      alert('Please select a user.');
      return;
    }
    this.householdsService.addMember(this.selectedHousehold.id, {
      appUserId: this.addMemberForm.appUserId,
      role: this.addMemberForm.role
    }).subscribe({
      next: () => {
        this.logger.info('MEMBER_ADDED', `Added user ${this.addMemberForm.appUserId} to household ${this.selectedHousehold!.id}`);
        this.addMemberForm = { appUserId: 0, selectedUsername: '', role: 'member' };
        this.userSearchTerm = '';
        this.loadDetail(this.selectedHousehold!.id);
      },
      error: (err) => {
        this.logger.err('MEMBER_ADD_ERROR', 'Failed to add member', err);
        alert(err.error?.error || 'Failed to add member.');
      }
    });
  }

  removeMember(appUserId: number): void {
    if (!this.selectedHousehold) return;
    if (!confirm('Remove this member from the household?')) return;
    this.householdsService.removeMember(this.selectedHousehold.id, appUserId).subscribe({
      next: () => {
        this.logger.warn('MEMBER_REMOVED', `Removed user ${appUserId} from household ${this.selectedHousehold!.id}`);
        this.loadDetail(this.selectedHousehold!.id);
      },
      error: (err) => {
        this.logger.err('MEMBER_REMOVE_ERROR', 'Failed to remove member', err);
        alert(err.error?.error || 'Failed to remove member.');
      }
    });
  }

  startEditRole(member: HouseholdMember): void {
    this.memberRoleEditing[member.appUserId] = member.role;
  }

  saveRole(member: HouseholdMember): void {
    if (!this.selectedHousehold) return;
    const newRole = this.memberRoleEditing[member.appUserId];
    this.householdsService.updateMemberRole(this.selectedHousehold.id, member.appUserId, newRole).subscribe({
      next: () => {
        this.logger.info('MEMBER_ROLE_UPDATED', `Updated role for user ${member.appUserId}`);
        delete this.memberRoleEditing[member.appUserId];
        this.loadDetail(this.selectedHousehold!.id);
      },
      error: (err) => {
        this.logger.err('MEMBER_ROLE_ERROR', 'Failed to update member role', err);
        alert(err.error?.error || 'Failed to update role.');
      }
    });
  }

  cancelEditRole(appUserId: number): void {
    delete this.memberRoleEditing[appUserId];
  }

  isEditingRole(appUserId: number): boolean {
    return appUserId in this.memberRoleEditing;
  }

  getInitials(username: string): string {
    return username ? username.slice(0, 2).toUpperCase() : '??';
  }

  // ── Expense Categories ─────────────────────────────────────────────────────

  loadExpenseCategories(): void {
    if (!this.selectedHousehold) return;
    this.expenseCatsLoading = true;
    this.householdsService.getExpenseCategories(this.selectedHousehold.id).pipe(takeUntil(this.destroy$)).subscribe({
      next: (res) => {
        this.expenseCategories = (Array.isArray(res) ? res : (res.data ?? [])).sort((a: Category, b: Category) => a.sortOrder - b.sortOrder);
        this.expenseCatsLoading = false;
      },
      error: (err) => {
        this.expenseCatsLoading = false;
        this.logger.err('EXPENSE_CATS_LOAD_ERROR', 'Failed to load expense categories', err);
      }
    });
  }

  openExpenseNewForm(): void {
    this.showExpenseNewForm = true;
    this.newExpenseCat = this.emptyCategory();
    this.editingExpenseCatId = null;
  }

  cancelExpenseNew(): void {
    this.showExpenseNewForm = false;
    this.showExpenseIconPicker = false;
  }

  saveExpenseNew(): void {
    if (!this.selectedHousehold || !this.newExpenseCat.name.trim()) {
      alert('Category name is required.');
      return;
    }
    const data = {
      name: this.newExpenseCat.name,
      icon: this.newExpenseCat.icon,
      color: this.newExpenseCat.color,
      budget: this.newExpenseCat.budget,
      householdId: this.selectedHousehold.id,
      sortOrder: this.expenseCategories.length + 1
    };
    this.householdsService.createExpenseCategory(data).subscribe({
      next: () => {
        this.logger.info('EXPENSE_CAT_CREATED', `Created expense category: ${data.name}`);
        this.showExpenseNewForm = false;
        this.loadExpenseCategories();
      },
      error: (err) => {
        this.logger.err('EXPENSE_CAT_CREATE_ERROR', 'Failed to create expense category', err);
        alert(err.error?.error || 'Failed to create category.');
      }
    });
  }

  startEditExpenseCat(cat: Category): void {
    this.editingExpenseCatId = cat.id;
    this.editingExpenseCat = { name: cat.name, icon: cat.icon, color: cat.color, budget: cat.budget ?? null };
    this.showExpenseNewForm = false;
    this.showExpenseEditIconPicker = false;
  }

  cancelEditExpenseCat(): void {
    this.editingExpenseCatId = null;
    this.showExpenseEditIconPicker = false;
  }

  saveEditExpenseCat(cat: Category): void {
    if (!this.editingExpenseCat.name.trim()) {
      alert('Category name is required.');
      return;
    }
    this.householdsService.updateExpenseCategory(cat.id, this.editingExpenseCat).subscribe({
      next: () => {
        this.logger.info('EXPENSE_CAT_UPDATED', `Updated expense category id=${cat.id}`);
        this.editingExpenseCatId = null;
        this.loadExpenseCategories();
      },
      error: (err) => {
        this.logger.err('EXPENSE_CAT_UPDATE_ERROR', 'Failed to update expense category', err);
        alert(err.error?.error || 'Failed to update category.');
      }
    });
  }

  deleteExpenseCat(id: number): void {
    if (!confirm('Delete this expense category?')) return;
    this.householdsService.deleteExpenseCategory(id).subscribe({
      next: () => {
        this.logger.warn('EXPENSE_CAT_DELETED', `Deleted expense category id=${id}`);
        this.loadExpenseCategories();
      },
      error: (err) => {
        this.logger.err('EXPENSE_CAT_DELETE_ERROR', 'Failed to delete expense category', err);
        alert(err.error?.error || 'Failed to delete category.');
      }
    });
  }

  moveExpenseCatUp(index: number): void {
    if (index === 0) return;
    const cats = [...this.expenseCategories];
    [cats[index - 1], cats[index]] = [cats[index], cats[index - 1]];
    this.reorderExpenseCats(cats);
  }

  moveExpenseCatDown(index: number): void {
    if (index === this.expenseCategories.length - 1) return;
    const cats = [...this.expenseCategories];
    [cats[index], cats[index + 1]] = [cats[index + 1], cats[index]];
    this.reorderExpenseCats(cats);
  }

  private reorderExpenseCats(cats: Category[]): void {
    const items = cats.map((c, i) => ({ id: c.id, sortOrder: i + 1 }));
    this.householdsService.reorderExpenseCategories(items).subscribe({
      next: () => {
        this.expenseCategories = cats.map((c, i) => ({ ...c, sortOrder: i + 1 }));
        this.logger.info('EXPENSE_CATS_REORDERED', 'Reordered expense categories');
      },
      error: (err) => {
        this.logger.err('EXPENSE_CATS_REORDER_ERROR', 'Failed to reorder expense categories', err);
        this.loadExpenseCategories();
      }
    });
  }

  // ── Income Categories ──────────────────────────────────────────────────────

  loadIncomeCategories(): void {
    if (!this.selectedHousehold) return;
    this.incomeCatsLoading = true;
    this.householdsService.getIncomeCategories(this.selectedHousehold.id).pipe(takeUntil(this.destroy$)).subscribe({
      next: (res) => {
        this.incomeCategories = (Array.isArray(res) ? res : (res.data ?? [])).sort((a: Category, b: Category) => a.sortOrder - b.sortOrder);
        this.incomeCatsLoading = false;
      },
      error: (err) => {
        this.incomeCatsLoading = false;
        this.logger.err('INCOME_CATS_LOAD_ERROR', 'Failed to load income categories', err);
      }
    });
  }

  openIncomeNewForm(): void {
    this.showIncomeNewForm = true;
    this.newIncomeCat = this.emptyCategory();
    this.editingIncomeCatId = null;
  }

  cancelIncomeNew(): void {
    this.showIncomeNewForm = false;
    this.showIncomeIconPicker = false;
  }

  saveIncomeNew(): void {
    if (!this.selectedHousehold || !this.newIncomeCat.name.trim()) {
      alert('Category name is required.');
      return;
    }
    const data = {
      name: this.newIncomeCat.name,
      icon: this.newIncomeCat.icon,
      color: this.newIncomeCat.color,
      householdId: this.selectedHousehold.id,
      sortOrder: this.incomeCategories.length + 1
    };
    this.householdsService.createIncomeCategory(data).subscribe({
      next: () => {
        this.logger.info('INCOME_CAT_CREATED', `Created income category: ${data.name}`);
        this.showIncomeNewForm = false;
        this.loadIncomeCategories();
      },
      error: (err) => {
        this.logger.err('INCOME_CAT_CREATE_ERROR', 'Failed to create income category', err);
        alert(err.error?.error || 'Failed to create category.');
      }
    });
  }

  startEditIncomeCat(cat: Category): void {
    this.editingIncomeCatId = cat.id;
    this.editingIncomeCat = { name: cat.name, icon: cat.icon, color: cat.color, budget: null };
    this.showIncomeNewForm = false;
    this.showIncomeEditIconPicker = false;
  }

  cancelEditIncomeCat(): void {
    this.editingIncomeCatId = null;
    this.showIncomeEditIconPicker = false;
  }

  saveEditIncomeCat(cat: Category): void {
    if (!this.editingIncomeCat.name.trim()) {
      alert('Category name is required.');
      return;
    }
    const data = { name: this.editingIncomeCat.name, icon: this.editingIncomeCat.icon, color: this.editingIncomeCat.color };
    this.householdsService.updateIncomeCategory(cat.id, data).subscribe({
      next: () => {
        this.logger.info('INCOME_CAT_UPDATED', `Updated income category id=${cat.id}`);
        this.editingIncomeCatId = null;
        this.loadIncomeCategories();
      },
      error: (err) => {
        this.logger.err('INCOME_CAT_UPDATE_ERROR', 'Failed to update income category', err);
        alert(err.error?.error || 'Failed to update category.');
      }
    });
  }

  deleteIncomeCat(id: number): void {
    if (!confirm('Delete this income category?')) return;
    this.householdsService.deleteIncomeCategory(id).subscribe({
      next: () => {
        this.logger.warn('INCOME_CAT_DELETED', `Deleted income category id=${id}`);
        this.loadIncomeCategories();
      },
      error: (err) => {
        this.logger.err('INCOME_CAT_DELETE_ERROR', 'Failed to delete income category', err);
        alert(err.error?.error || 'Failed to delete category.');
      }
    });
  }

  moveIncomeCatUp(index: number): void {
    if (index === 0) return;
    const cats = [...this.incomeCategories];
    [cats[index - 1], cats[index]] = [cats[index], cats[index - 1]];
    this.reorderIncomeCats(cats);
  }

  moveIncomeCatDown(index: number): void {
    if (index === this.incomeCategories.length - 1) return;
    const cats = [...this.incomeCategories];
    [cats[index], cats[index + 1]] = [cats[index + 1], cats[index]];
    this.reorderIncomeCats(cats);
  }

  private reorderIncomeCats(cats: Category[]): void {
    const items = cats.map((c, i) => ({ id: c.id, sortOrder: i + 1 }));
    this.householdsService.reorderIncomeCategories(items).subscribe({
      next: () => {
        this.incomeCategories = cats.map((c, i) => ({ ...c, sortOrder: i + 1 }));
        this.logger.info('INCOME_CATS_REORDERED', 'Reordered income categories');
      },
      error: (err) => {
        this.logger.err('INCOME_CATS_REORDER_ERROR', 'Failed to reorder income categories', err);
        this.loadIncomeCategories();
      }
    });
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  private emptyCategory(): CategoryForm {
    return { name: '', icon: 'home', color: '#3F51B5', budget: null };
  }

  trackById(index: number, item: { id: number }): number {
    return item.id;
  }

  trackByIndex(index: number): number {
    return index;
  }
}
