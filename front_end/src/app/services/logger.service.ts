import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { AuthService } from './auth.service';
import { interval, Observable, Subject } from 'rxjs';
import { takeUntil } from 'rxjs/operators';
import { getBaseAddress } from '../utils/get-base-address';

interface LogEntry {
  level: 'debug' | 'info' | 'warn' | 'err';
  action: string;
  description?: string;
  data?: any;
  timestamp: Date;
  metadata?: any;
}

@Injectable({
  providedIn: 'root'
})
export class LoggerService {
  private apiUrl = getBaseAddress() + '/api';
  private logBatch: LogEntry[] = [];
  private batchSize = 100;
  private batchInterval = 30000; // 30 seconds
  private destroy$ = new Subject<void>();

  constructor(
    private http: HttpClient,
    private authService: AuthService
  ) {
    this.initializeBatchProcessor();
    this.setupErrorHandlers();
  }

  // Initialize batch processing - The Force awakens! 🌟
  private initializeBatchProcessor(): void {
    // Process batch every 30 seconds
    interval(this.batchInterval)
      .pipe(takeUntil(this.destroy$))
      .subscribe(() => {
        this.processBatch();
      });

    // Process on page unload
    window.addEventListener('beforeunload', () => {
      this.processBatch(true);
    });
  }

  // Setup global error handlers - Jedi error catching! 🛡️
  private setupErrorHandlers(): void {
    // Catch unhandled errors
    window.addEventListener('error', (event) => {
      this.err('UNHANDLED_ERROR', event.message, {
        filename: event.filename,
        lineno: event.lineno,
        colno: event.colno,
        error: event.error?.stack || event.error
      });
    });

    // Catch unhandled promise rejections
    window.addEventListener('unhandledrejection', (event) => {
      this.err('UNHANDLED_REJECTION', 'Unhandled promise rejection', {
        reason: event.reason,
        promise: event.promise
      });
    });
  }

  // Core logging method
  private log(level: LogEntry['level'], action: string, description?: string, data?: any, metadata?: any): void {
    const logEntry: LogEntry = {
      level,
      action,
      description,
      data,
      timestamp: new Date(),
      metadata: {
        ...metadata,
        url: window.location.href,
        userAgent: navigator.userAgent
      }
    };

    // Console output in development
    if (!this.isProduction()) {
      const color = this.getConsoleColor(level);
      console.log(
        `%c[${logEntry.timestamp.toISOString()}] [${level.toUpperCase()}] ${action}`,
        `color: ${color}; font-weight: bold`
      );
      if (description) console.log('Description:', description);
      if (data) console.log('Data:', data);
    }

    // Add to batch
    this.logBatch.push(logEntry);

    // Immediate send for errors
    if (level === 'err') {
      this.processBatch(true);
    } else if (this.logBatch.length >= this.batchSize) {
      this.processBatch();
    }
  }

  // Public logging methods - May the logs be with you! 
  debug(action: string, description?: string, data?: any, metadata?: any): void {
    this.log('debug', action, description, data, metadata);
  }

  info(action: string, description?: string, data?: any, metadata?: any): void {
    this.log('info', action, description, data, metadata);
  }

  warn(action: string, description?: string, data?: any, metadata?: any): void {
    this.log('warn', action, description, data, metadata);
  }

  err(action: string, description?: string, data?: any, metadata?: any): void {
    this.log('err', action, description, data, metadata);
  }

  // Process and send batch
  private processBatch(forceSend: boolean = false): void {
    if (this.logBatch.length === 0) return;

    // Don't send if not authenticated (unless errors)
    if (!this.authService.isLoggedIn() && !forceSend) {
      return;
    }

    const batch = [...this.logBatch];
    this.logBatch = [];

    this.sendLogs(batch).subscribe({
      next: (response) => {
        if (!this.isProduction()) {
          console.log(`✅ Sent ${batch.length} logs to server`);
        }
      },
      error: (error) => {
        console.error('Failed to send logs:', error);
        // Re-add non-error logs to batch for retry
        const nonErrorLogs = batch.filter(log => log.level !== 'err');
        this.logBatch.unshift(...nonErrorLogs);
      }
    });
  }

  // Send logs to backend
  private sendLogs(logs: LogEntry[]): Observable<any> {
    const headers = new HttpHeaders({
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${this.authService.getToken()}`
    });

    return this.http.post(`${this.apiUrl}/logs/batch`, {
      logs: logs.map(log => ({
        ...log,
        source: 'frontend'
      }))
    }, { headers });
  }

  // Helper methods
  private getConsoleColor(level: LogEntry['level']): string {
    const colors = {
      debug: '#00bcd4',
      info: '#4caf50',
      warn: '#ff9800',
      err: '#f44336'
    };
    return colors[level] || '#000';
  }

  private isProduction(): boolean {
    return window.location.hostname !== 'localhost';
  }

  // Component lifecycle tracking
  logNavigation(from: string, to: string): void {
    this.info('NAVIGATION', `Navigated from ${from} to ${to}`, {
      from,
      to,
      timestamp: new Date()
    });
  }

  logComponentInit(componentName: string): void {
    this.debug('COMPONENT_INIT', `${componentName} initialized`);
  }

  logComponentDestroy(componentName: string): void {
    this.debug('COMPONENT_DESTROY', `${componentName} destroyed`);
  }

  // API tracking
  logApiCall(method: string, endpoint: string, duration: number, status: number): void {
    const level = status >= 400 ? 'err' : 'info';
    this.log(level, 'API_CALL', `${method} ${endpoint}`, {
      method,
      endpoint,
      duration,
      status
    });
  }

  // Cleanup
  ngOnDestroy(): void {
    this.processBatch(true);
    this.destroy$.next();
    this.destroy$.complete();
  }
}