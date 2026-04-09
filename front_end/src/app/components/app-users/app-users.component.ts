import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { HttpClient } from '@angular/common/http';
import { Subject, debounceTime, distinctUntilChanged, takeUntil } from 'rxjs';
import { AppUsersService } from '../../services/app-users.service';
import { LoggerService } from '../../services/logger.service';

interface AppUser {
    id: number;
    username: string;
    isActive: boolean;
    isDeveloper: boolean;
    lastLogin: string | null;
    households: string[];
}

interface CreateUserForm {
    username: string;
    password: string;
}

interface EditUserForm {
    username: string;
    isActive: boolean;
    isDeveloper: boolean;
}

interface ResetPasswordForm {
    newPassword: string;
    confirmPassword: string;
}

@Component({
    selector: 'app-app-users',
    standalone: true,
    imports: [CommonModule, FormsModule],
    templateUrl: './app-users.component.html',
    styleUrls: ['./app-users.component.css']
})
export class AppUsersComponent implements OnInit, OnDestroy {
    users: AppUser[] = [];
    loading = false;
    error = '';

    // Pagination
    currentPage = 1;
    totalPages = 1;
    itemsPerPage = 20;
    totalItems = 0;

    // Search
    searchTerm = '';
    private searchSubject = new Subject<string>();
    private destroy$ = new Subject<void>();

    // Create modal
    showCreateModal = false;
    createForm: CreateUserForm = this.getEmptyCreateForm();
    createError = '';
    createLoading = false;

    // Edit modal
    showEditModal = false;
    editingUser: AppUser | null = null;
    editForm: EditUserForm = { username: '', isActive: true, isDeveloper: false };
    editError = '';
    editLoading = false;

    // Reset password modal
    showResetModal = false;
    resetUserId: number | null = null;
    resetUsername = '';
    resetForm: ResetPasswordForm = { newPassword: '', confirmPassword: '' };
    resetError = '';
    resetLoading = false;

    // Delete confirmation (inline per row)
    deletingId: number | null = null;
    deleteLoading = false;

    constructor(
        private appUsersService: AppUsersService,
        private logger: LoggerService
    ) { }

    ngOnInit(): void {
        this.logger.logComponentInit('AppUsersComponent');

        this.searchSubject
            .pipe(
                debounceTime(500),
                distinctUntilChanged(),
                takeUntil(this.destroy$)
            )
            .subscribe(searchTerm => {
                this.searchTerm = searchTerm;
                this.currentPage = 1;
                this.loadUsers();
            });

        this.loadUsers();
    }

    ngOnDestroy(): void {
        this.logger.logComponentDestroy('AppUsersComponent');
        this.destroy$.next();
        this.destroy$.complete();
    }

    loadUsers(): void {
        this.loading = true;
        this.error = '';

        this.appUsersService.getAppUsers(this.currentPage, this.itemsPerPage, this.searchTerm).subscribe({
            next: (response) => {
                this.users = response.users;
                this.totalPages = response.pagination.pages;
                this.totalItems = response.pagination.total;
                this.loading = false;
                this.logger.info('APP_USERS_LOADED', `Loaded ${response.data.length} users`, {
                    page: this.currentPage,
                    total: response.pagination.total
                });
            },
            error: (err) => {
                this.error = 'Failed to load users.';
                this.loading = false;
                this.logger.err('APP_USERS_LOAD_ERROR', 'Failed to load app users', err);
            }
        });
    }

    // Search
    onSearchChange(value: string): void {
        this.searchSubject.next(value);
    }

    clearSearch(): void {
        this.searchTerm = '';
        this.currentPage = 1;
        this.loadUsers();
    }

    // Pagination
    prevPage(): void {
        if (this.currentPage > 1) {
            this.currentPage--;
            this.loadUsers();
        }
    }

    nextPage(): void {
        if (this.currentPage < this.totalPages) {
            this.currentPage++;
            this.loadUsers();
        }
    }

    goToPage(page: number): void {
        if (page >= 1 && page <= this.totalPages) {
            this.currentPage = page;
            this.loadUsers();
        }
    }

    // Create
    openCreateModal(): void {
        this.createForm = this.getEmptyCreateForm();
        this.createError = '';
        this.showCreateModal = true;
    }

    closeCreateModal(): void {
        this.showCreateModal = false;
        this.createForm = this.getEmptyCreateForm();
        this.createError = '';
    }

    submitCreate(): void {
        if (!this.createForm.username.trim()) {
            this.createError = 'Username is required.';
            return;
        }
        if (!this.createForm.password) {
            this.createError = 'Password is required.';
            return;
        }

        this.createLoading = true;
        this.createError = '';

        this.appUsersService.createAppUser({
            username: this.createForm.username.trim(),
            password: this.createForm.password
        }).subscribe({
            next: () => {
                this.logger.info('APP_USER_CREATED', `Created user: ${this.createForm.username}`);
                this.createLoading = false;
                this.closeCreateModal();
                this.loadUsers();
            },
            error: (err) => {
                this.createError = err.error?.error || 'Failed to create user.';
                this.createLoading = false;
                this.logger.err('APP_USER_CREATE_ERROR', 'Failed to create app user', err);
            }
        });
    }

    // Edit
    openEditModal(user: AppUser): void {
        this.editingUser = user;
        this.editForm = { username: user.username, isActive: user.isActive, isDeveloper: user.isDeveloper };
        this.editError = '';
        this.showEditModal = true;
    }

    closeEditModal(): void {
        this.showEditModal = false;
        this.editingUser = null;
        this.editError = '';
    }

    submitEdit(): void {
        if (!this.editingUser) return;
        if (!this.editForm.username.trim()) {
            this.editError = 'Username is required.';
            return;
        }

        this.editLoading = true;
        this.editError = '';

        this.appUsersService.updateAppUser(this.editingUser.id, {
            username: this.editForm.username.trim(),
            isActive: this.editForm.isActive,
            isDeveloper: this.editForm.isDeveloper
        }).subscribe({
            next: () => {
                this.logger.info('APP_USER_UPDATED', `Updated user: ${this.editForm.username}`);
                this.editLoading = false;
                this.closeEditModal();
                this.loadUsers();
            },
            error: (err) => {
                this.editError = err.error?.error || 'Failed to update user.';
                this.editLoading = false;
                this.logger.err('APP_USER_UPDATE_ERROR', 'Failed to update app user', err);
            }
        });
    }

    // Reset password
    openResetModal(user: AppUser): void {
        this.resetUserId = user.id;
        this.resetUsername = user.username;
        this.resetForm = { newPassword: '', confirmPassword: '' };
        this.resetError = '';
        this.showResetModal = true;
    }

    closeResetModal(): void {
        this.showResetModal = false;
        this.resetUserId = null;
        this.resetUsername = '';
        this.resetError = '';
    }

    submitResetPassword(): void {
        if (!this.resetForm.newPassword) {
            this.resetError = 'New password is required.';
            return;
        }
        if (this.resetForm.newPassword !== this.resetForm.confirmPassword) {
            this.resetError = 'Passwords do not match.';
            return;
        }
        if (!this.resetUserId) return;

        this.resetLoading = true;
        this.resetError = '';

        this.appUsersService.resetPassword(this.resetUserId, this.resetForm.newPassword).subscribe({
            next: () => {
                this.logger.info('APP_USER_PASSWORD_RESET', `Password reset for user id: ${this.resetUserId}`);
                this.resetLoading = false;
                this.closeResetModal();
            },
            error: (err) => {
                this.resetError = err.error?.error || 'Failed to reset password.';
                this.resetLoading = false;
                this.logger.err('APP_USER_RESET_ERROR', 'Failed to reset password', err);
            }
        });
    }

    // Delete
    confirmDelete(userId: number): void {
        this.deletingId = userId;
    }

    cancelDelete(): void {
        this.deletingId = null;
    }

    executeDelete(user: AppUser): void {
        this.deleteLoading = true;

        this.appUsersService.deleteAppUser(user.id).subscribe({
            next: () => {
                this.logger.warn('APP_USER_DELETED', `Deleted user: ${user.username}`);
                this.deleteLoading = false;
                this.deletingId = null;
                this.loadUsers();
            },
            error: (err) => {
                this.deleteLoading = false;
                this.deletingId = null;
                this.error = err.error?.error || 'Failed to delete user.';
                this.logger.err('APP_USER_DELETE_ERROR', 'Failed to delete app user', err);
            }
        });
    }

    // Helpers
    getEmptyCreateForm(): CreateUserForm {
        return { username: '', password: '' };
    }

    formatLastLogin(lastLogin: string | null): string {
        if (!lastLogin) return 'Never';
        const date = new Date(lastLogin);
        return date.toLocaleString();
    }

    formatHouseholds(households: string[]): string {
        if (!households || households.length === 0) return '-';
        return households.join(', ');
    }

    trackByUserId(index: number, user: AppUser): number {
        return user.id;
    }
}
