import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { SettingsService } from '../../services/settings.service';
import { LoggerService } from '../../services/logger.service';
import { Subject, debounceTime, distinctUntilChanged, takeUntil } from 'rxjs';

interface Setting {
  id: number;
  key: string;
  value: string;
  description: string;
  core_setting: boolean;
  sendWithConfig: boolean;
}

interface SettingForm {
  key: string;
  value: string;
  description: string;
  sendWithConfig: boolean;
}

@Component({
  selector: 'app-settings',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './settings.component.html',
  styleUrls: ['./settings.component.css']
})
export class SettingsComponent implements OnInit, OnDestroy {
  settings: Setting[] = [];
  loading = false;
  error = '';

  // Pagination - Navigate through configurations! 🔧
  currentPage = 1;
  totalPages = 1;
  itemsPerPage = 20;

  // Filters
  searchTerm = '';
  filterCore: string = ''; // '', 'true', 'false'
  filterConfig: string = ''; // '', 'true', 'false'

  // Form handling
  showAddForm = false;
  editingId: number | null = null;
  newSetting: SettingForm = this.getEmptyForm();
  editingValue: { [key: number]: string } = {};
  editingDescription: { [key: number]: string } = {};
  editingConfig: { [key: number]: boolean } = {};

  // Search debounce
  private searchSubject = new Subject<string>();
  private destroy$ = new Subject<void>();

  // View options
  viewMode: 'table' | 'cards' = 'table';

  constructor(
    private settingsService: SettingsService,
    private logger: LoggerService
  ) { }

  ngOnInit(): void {
    this.logger.logComponentInit('SettingsComponent');

    // Setup search debounce
    this.searchSubject
      .pipe(
        debounceTime(500),
        distinctUntilChanged(),
        takeUntil(this.destroy$)
      )
      .subscribe(searchTerm => {
        this.searchTerm = searchTerm;
        this.currentPage = 1;
        this.loadSettings();
      });

    this.loadSettings();
  }

  ngOnDestroy(): void {
    this.logger.logComponentDestroy('SettingsComponent');
    this.destroy$.next();
    this.destroy$.complete();
  }

  loadSettings(): void {
    this.loading = true;
    this.error = '';

    const filters: any = {
      page: this.currentPage,
      limit: this.itemsPerPage
    };

    if (this.searchTerm) filters.search = this.searchTerm;
    if (this.filterCore) filters.core = this.filterCore;
    if (this.filterConfig) filters.sendWithConfig = this.filterConfig;

    this.settingsService.getSettings(filters).subscribe({
      next: (response) => {
        this.settings = response.data;
        this.totalPages = response.pagination.pages;
        this.loading = false;

        this.logger.info('SETTINGS_LOADED', `Loaded ${response.data.length} settings`, {
          filters,
          total: response.pagination.total
        });
      },
      error: (err) => {
        this.error = 'Failed to load settings. Configuration locked!';
        this.loading = false;
        this.logger.err('SETTINGS_LOAD_ERROR', 'Failed to load settings', err);
      }
    });
  }

  // Filter methods
  onSearchChange(searchTerm: string): void {
    this.searchSubject.next(searchTerm);
  }

  onFilterChange(): void {
    this.currentPage = 1;
    this.loadSettings();
  }

  clearFilters(): void {
    this.searchTerm = '';
    this.filterCore = '';
    this.filterConfig = '';
    this.currentPage = 1;
    this.loadSettings();
    this.logger.info('SETTINGS_FILTERS_CLEARED', 'All filters cleared');
  }

  // CRUD Operations
  showAddSettingForm(): void {
    this.showAddForm = true;
    this.newSetting = this.getEmptyForm();
  }

  cancelAdd(): void {
    this.showAddForm = false;
    this.newSetting = this.getEmptyForm();
  }

  addSetting(): void {
    if (!this.newSetting.key.trim()) {
      alert('Setting key is required!');
      return;
    }

    this.settingsService.createSetting(this.newSetting).subscribe({
      next: () => {
        this.logger.info('SETTING_CREATED', `Created setting: ${this.newSetting.key}`);
        this.showAddForm = false;
        this.newSetting = this.getEmptyForm();
        this.loadSettings();
      },
      error: (err) => {
        this.logger.err('CREATE_SETTING_ERROR', 'Failed to create setting', err);
        alert(err.error?.error || 'Failed to create setting!');
      }
    });
  }

  startEdit(setting: Setting): void {
    this.editingId = setting.id;
    this.editingValue[setting.id] = setting.value || '';
    this.editingDescription[setting.id] = setting.description || '';
    this.editingConfig[setting.id] = setting.sendWithConfig;
  }

  cancelEdit(settingId: number): void {
    this.editingId = null;
    delete this.editingValue[settingId];
    delete this.editingDescription[settingId];
    delete this.editingConfig[settingId];
  }

  saveEdit(setting: Setting): void {
    const updates = {
      value: this.editingValue[setting.id],
      description: this.editingDescription[setting.id],
      sendWithConfig: this.editingConfig[setting.id]
    };

    this.settingsService.updateSetting(setting.id, updates).subscribe({
      next: () => {
        this.logger.info('SETTING_UPDATED', `Updated setting: ${setting.key}`);
        this.editingId = null;
        this.loadSettings();
      },
      error: (err) => {
        this.logger.err('UPDATE_SETTING_ERROR', 'Failed to update setting', err);
        alert('Failed to update setting!');
      }
    });
  }

  deleteSetting(setting: Setting): void {
    if (setting.core_setting) {
      alert('Core settings cannot be deleted!');
      return;
    }

    if (!confirm(`Are you sure you want to delete the setting "${setting.key}"?`)) {
      return;
    }

    this.settingsService.deleteSetting(setting.id).subscribe({
      next: () => {
        this.logger.warn('SETTING_DELETED', `Deleted setting: ${setting.key}`);
        this.loadSettings();
      },
      error: (err) => {
        this.logger.err('DELETE_SETTING_ERROR', 'Failed to delete setting', err);
        alert(err.error?.error || 'Failed to delete setting!');
      }
    });
  }

  // Helper methods
  getEmptyForm(): SettingForm {
    return {
      key: '',
      value: '',
      description: '',
      sendWithConfig: false
    };
  }

  getSettingTypeIcon(setting: Setting): string {
    if (setting.core_setting) return 'core';
    if (setting.sendWithConfig) return 'config';
    return 'regular';
  }

  getSettingTypeTooltip(setting: Setting): string {
    if (setting.core_setting) return 'Core Setting (Protected)';
    if (setting.sendWithConfig) return 'Sent with Config';
    return 'Standard Setting';
  }

  isValidJson(value: string): boolean {
    if (!value) return true;
    try {
      JSON.parse(value);
      return true;
    } catch {
      return false;
    }
  }

  // Pagination
  nextPage(): void {
    if (this.currentPage < this.totalPages) {
      this.currentPage++;
      this.loadSettings();
    }
  }

  prevPage(): void {
    if (this.currentPage > 1) {
      this.currentPage--;
      this.loadSettings();
    }
  }

  goToPage(page: number): void {
    if (page >= 1 && page <= this.totalPages) {
      this.currentPage = page;
      this.loadSettings();
    }
  }

  // Export settings
  exportSettings(): void {
    this.logger.info('SETTINGS_EXPORT', 'Exporting settings');

    this.settingsService.getSettings({ limit: 1000 }).subscribe({
      next: (response) => {
        const settings = response.data.map((s: Setting) => ({
          key: s.key,
          value: s.value,
          description: s.description,
          core_setting: s.core_setting,
          sendWithConfig: s.sendWithConfig
        }));

        const blob = new Blob([JSON.stringify(settings, null, 2)], { type: 'application/json' });
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `settings_${new Date().toISOString().split('T')[0]}.json`;
        link.click();
        window.URL.revokeObjectURL(url);
      },
      error: (err) => {
        this.logger.err('EXPORT_ERROR', 'Failed to export settings', err);
        alert('Failed to export settings!');
      }
    });
  }

  trackBySettingId(index: number, setting: Setting): number {
    return setting.id;
  }
}