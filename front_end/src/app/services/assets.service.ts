import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AppAuthService } from './app-auth.service';
import { getApiUrl } from '../utils/get-base-address';

export interface Asset {
  id: number;
  name: string;
  value: number;
  liquidity: 'high' | 'medium' | 'low';
  description: string;
  householdId: number;
  sortOrder: number;
  date?: string | null;

  // Exit fields
  exitType?: 'none' | 'single' | 'series';
  exitDate?: string | null;
  exitSeriesStart?: string | null;
  exitSeriesInterval?: number | null;
  exitSeriesUnit?: 'days' | 'weeks' | 'months' | 'years' | null;

  // Repetitive income fields
  isRepetitive?: boolean;
  repetitiveAmount?: number | null;
  repetitiveInterval?: number | null;
  repetitiveUnit?: 'days' | 'weeks' | 'months' | 'years' | null;
}

@Injectable({ providedIn: 'root' })
export class AssetsService {
  private apiUrl = getApiUrl() + '/app/assets';

  constructor(private http: HttpClient, private appAuthService: AppAuthService) {}

  private getHeaders(): HttpHeaders {
    const token = this.appAuthService.getToken();
    return new HttpHeaders({ Authorization: `Bearer ${token}` });
  }

  list(householdId: number): Observable<{ success: boolean; assets: Asset[]; groupTotals: Record<string, number> }> {
    const params = new HttpParams().set('householdId', householdId.toString());
    return this.http.get<any>(this.apiUrl, { headers: this.getHeaders(), params });
  }

  create(data: Partial<Asset>): Observable<{ success: boolean; asset: Asset }> {
    return this.http.post<any>(this.apiUrl, data, { headers: this.getHeaders() });
  }

  reorder(order: { id: number; sortOrder: number }[]): Observable<{ success: boolean }> {
    return this.http.put<any>(`${this.apiUrl}/reorder`, { order }, { headers: this.getHeaders() });
  }

  update(id: number, data: Partial<Asset>): Observable<{ success: boolean; asset: Asset }> {
    return this.http.put<any>(`${this.apiUrl}/${id}`, data, { headers: this.getHeaders() });
  }

  delete(id: number): Observable<{ success: boolean }> {
    return this.http.delete<any>(`${this.apiUrl}/${id}`, { headers: this.getHeaders() });
  }
}
