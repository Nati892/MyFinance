import { Component, OnInit, OnDestroy } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { ApiService, LogFilters } from '../../services/api.service';
import { LoggerService } from '../../services/logger.service';
import { Subject, debounceTime, distinctUntilChanged, takeUntil } from 'rxjs';

interface DatePreset {
  label: string;
  value: string;
}

@Component({
  selector: 'app-logs',
  standalone: true,
  imports: [CommonModule, FormsModule],
  templateUrl: './logs.component.html',
  styleUrls: ['./logs.component.css']
})
export class LogsComponent implements OnInit, OnDestroy {
  logs: any[] = [];
  loading = false;
  error = '';

  // Pagination - Navigate through the archives! 📚
  currentPage = 1;
  totalPages = 1;
  itemsPerPage = 20;

  // Filters - The tools of a master searcher! 🔍
  filters: LogFilters = {
    page: 1,
    limit: 20
  };

  // Filter options
  availableLevels: string[] = [];
  availableSources: string[] = [];
  availableActions: string[] = [];
  availableUsers: Array<{ id: number; username: string }> = [];

  // Date presets - Time is our ally! ⏱️
  datePresets: DatePreset[] = [
    { label: 'Today', value: 'today' },
    { label: 'Yesterday', value: 'yesterday' },
    { label: 'Last 7 Days', value: 'last7days' },
    { label: 'Last 30 Days', value: 'last30days' },
    { label: 'This Month', value: 'thisMonth' },
    { label: 'Last Month', value: 'lastMonth' },
    { label: 'Custom Range', value: 'custom' }
  ];

  selectedPreset = '';
  showCustomDate = false;

  // Search debounce
  private searchSubject = new Subject<string>();
  private destroy$ = new Subject<void>();

  // View options
  expandedLogId: number | null = null;
  viewMode: 'table' | 'cards' = 'table';

  constructor(
    private apiService: ApiService,
    private logger: LoggerService
  ) { }

  ngOnInit(): void {
    this.logger.logComponentInit('LogsComponent');

    // Setup search debounce - Patience, young padawan! 🧘
    this.searchSubject
      .pipe(
        debounceTime(500),
        distinctUntilChanged(),
        takeUntil(this.destroy$)
      )
      .subscribe(searchTerm => {
        this.filters.search = searchTerm;
        this.filters.page = 1; // Reset to first page
        this.loadLogs();
      });

    this.loadLogs();
  }

  ngOnDestroy(): void {
    this.logger.logComponentDestroy('LogsComponent');
    this.destroy$.next();
    this.destroy$.complete();
  }

  loadLogs(): void {
    this.loading = true;
    this.error = '';

    this.apiService.getLogs(this.filters).subscribe({
      next: (response) => {
        this.logs = response.data;
        this.totalPages = response.pagination.pages;
        this.currentPage = response.pagination.page;

        // Update available filter options
        this.availableLevels = response.filters.levels;
        this.availableSources = response.filters.sources;
        this.availableActions = response.filters.actions;
        this.availableUsers = response.filters.users;

        this.loading = false;

        this.logger.info('LOGS_LOADED', `Loaded ${response.data.length} logs`, {
          filters: this.filters,
          total: response.pagination.total
        });
      },
      error: (err) => {
        this.error = 'Failed to load logs. The archives are sealed!';
        this.loading = false;
        this.logger.err('LOGS_LOAD_ERROR', 'Failed to load logs', err);
      }
    });
  }

  // Filter methods - Master the search! 🎯
  onSearchChange(searchTerm: string): void {
    this.searchSubject.next(searchTerm);
  }

  onFilterChange(): void {
    this.filters.page = 1; // Reset to first page
    this.loadLogs();
  }

  onPresetChange(): void {
    if (this.selectedPreset === 'custom') {
      this.showCustomDate = true;
      this.filters.preset = undefined;
    } else {
      this.showCustomDate = false;
      this.filters.preset = this.selectedPreset;
      this.filters.dateFrom = undefined;
      this.filters.dateTo = undefined;
      this.onFilterChange();
    }
  }

  onDateRangeChange(): void {
    if (this.showCustomDate) {
      this.filters.preset = undefined;
      this.onFilterChange();
    }
  }

  clearFilters(): void {
    this.filters = {
      page: 1,
      limit: this.itemsPerPage
    };
    this.selectedPreset = '';
    this.showCustomDate = false;
    this.loadLogs();

    this.logger.info('FILTERS_CLEARED', 'All filters cleared');
  }

  // Pagination - Navigate the archives! 📖
  nextPage(): void {
    if (this.currentPage < this.totalPages) {
      this.filters.page = this.currentPage + 1;
      this.loadLogs();
    }
  }

  prevPage(): void {
    if (this.currentPage > 1) {
      this.filters.page = this.currentPage - 1;
      this.loadLogs();
    }
  }

  goToPage(page: number): void {
    if (page >= 1 && page <= this.totalPages) {
      this.filters.page = page;
      this.loadLogs();
    }
  }

  // View methods - Expand your vision! 👁️
  toggleLogDetails(logId: number): void {
    this.expandedLogId = this.expandedLogId === logId ? null : logId;
  }

  getLogLevelClass(level: string): string {
    const classes = {
      'debug': 'log-debug',
      'info': 'log-info',
      'warn': 'log-warn',
      'err': 'log-error'
    };
    return classes[level as keyof typeof classes] || '';
  }

  formatJson(data: any): string {
    try {
      return JSON.stringify(data, null, 2);
    } catch {
      return String(data);
    }
  }

  // Export logs - Download the wisdom! 💾
  exportLogs(): void {
    this.logger.info('LOGS_EXPORT', 'Exporting logs', { filters: this.filters });

    this.apiService.exportLogs(this.filters).subscribe({
      next: (blob) => {
        const url = window.URL.createObjectURL(blob);
        const link = document.createElement('a');
        link.href = url;
        link.download = `logs_${new Date().toISOString().split('T')[0]}.csv`;
        link.click();
        window.URL.revokeObjectURL(url);
      },
      error: (err) => {
        this.logger.err('EXPORT_ERROR', 'Failed to export logs', err);
        alert('Failed to export logs!');
      }
    });
  }
  
  trackByLogId(index: number, log: any): number {
    return log.id;
  }

  hasKeys(obj: any): boolean {
    return obj && Object.keys(obj).length > 0;
  }

}