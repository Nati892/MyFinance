import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AuthService } from './auth.service';
import { getBaseAddress } from '../utils/get-base-address';

export interface LogFilters {
  page?: number;
  limit?: number;
  level?: string;
  source?: string;
  userId?: number;
  action?: string;
  search?: string;
  dateFrom?: string;
  dateTo?: string;
  preset?: string;
}

export interface LogResponse {
  success: boolean;
  data: any[];
  pagination: {
    page: number;
    limit: number;
    total: number;
    pages: number;
  };
  filters: {
    levels: string[];
    sources: string[];
    actions: string[];
    users: Array<{ id: number; username: string }>;
  };
}

@Injectable({
  providedIn: 'root'
})
export class ApiService {
  private apiUrl = getBaseAddress() + '/api';

  constructor(
    private http: HttpClient,
    private authService: AuthService
  ) { }

  private getHeaders(): HttpHeaders {
    const token = this.authService.getToken();
    return new HttpHeaders({
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${token}`
    });
  }

  getLogs(filters: LogFilters = {}): Observable<LogResponse> {
    let params = new HttpParams();

    // Build query params - The Force flows through our filters! 🌊
    Object.keys(filters).forEach(key => {
      const value = filters[key as keyof LogFilters];
      if (value !== null && value !== undefined && value !== '') {
        params = params.set(key, value.toString());
      }
    });

    return this.http.get<LogResponse>(`${this.apiUrl}/logs`, {
      headers: this.getHeaders(),
      params
    });
  }

  // Get log statistics - Analyze the patterns in the Force! 📊
  getLogStats(): Observable<any> {
    return this.http.get(`${this.apiUrl}/logs/stats`, {
      headers: this.getHeaders()
    });
  }

  // Export logs - Download the archives! 📥
  exportLogs(filters: LogFilters): Observable<Blob> {
    let params = new HttpParams();
    Object.keys(filters).forEach(key => {
      const value = filters[key as keyof LogFilters];
      if (value !== null && value !== undefined && value !== '') {
        params = params.set(key, value.toString());
      }
    });

    return this.http.get(`${this.apiUrl}/logs/export`, {
      headers: this.getHeaders(),
      params,
      responseType: 'blob'
    });
  }
}