import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AuthService } from './auth.service';
import { getApiUrl } from '../utils/get-base-address';

@Injectable({
  providedIn: 'root'
})
export class HouseholdsService {
  private apiUrl = getApiUrl();

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

  // ── Households ────────────────────────────────────────────────────────────

  getHouseholds(page = 1, limit = 50): Observable<any> {
    const params = new HttpParams()
      .set('page', page.toString())
      .set('limit', limit.toString());
    return this.http.get(`${this.apiUrl}/households`, { headers: this.getHeaders(), params });
  }

  getHousehold(id: number): Observable<any> {
    return this.http.get(`${this.apiUrl}/households/${id}`, { headers: this.getHeaders() });
  }

  createHousehold(data: { name: string; description: string }): Observable<any> {
    return this.http.post(`${this.apiUrl}/households`, data, { headers: this.getHeaders() });
  }

  updateHousehold(id: number, data: { name?: string; description?: string }): Observable<any> {
    return this.http.put(`${this.apiUrl}/households/${id}`, data, { headers: this.getHeaders() });
  }

  deleteHousehold(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/households/${id}`, { headers: this.getHeaders() });
  }

  // ── Members ───────────────────────────────────────────────────────────────

  addMember(id: number, data: { appUserId: number; role: string }): Observable<any> {
    return this.http.post(`${this.apiUrl}/households/${id}/members`, data, { headers: this.getHeaders() });
  }

  removeMember(id: number, appUserId: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/households/${id}/members/${appUserId}`, { headers: this.getHeaders() });
  }

  updateMemberRole(id: number, appUserId: number, role: string): Observable<any> {
    return this.http.put(`${this.apiUrl}/households/${id}/members/${appUserId}`, { role }, { headers: this.getHeaders() });
  }

  // ── App Users ─────────────────────────────────────────────────────────────

  getAppUsers(): Observable<any> {
    return this.http.get(`${this.apiUrl}/app-users`, { headers: this.getHeaders() });
  }

  // ── Expense Categories ────────────────────────────────────────────────────

  getExpenseCategories(householdId: number): Observable<any> {
    const params = new HttpParams().set('householdId', householdId.toString());
    return this.http.get(`${this.apiUrl}/admin/expense-categories`, { headers: this.getHeaders(), params });
  }

  createExpenseCategory(data: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/admin/expense-categories`, data, { headers: this.getHeaders() });
  }

  updateExpenseCategory(id: number, data: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/admin/expense-categories/${id}`, data, { headers: this.getHeaders() });
  }

  deleteExpenseCategory(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/admin/expense-categories/${id}`, { headers: this.getHeaders() });
  }

  reorderExpenseCategories(items: { id: number; sortOrder: number }[]): Observable<any> {
    return this.http.put(`${this.apiUrl}/admin/expense-categories/reorder`, { items }, { headers: this.getHeaders() });
  }

  // ── Income Categories ─────────────────────────────────────────────────────

  getIncomeCategories(householdId: number): Observable<any> {
    const params = new HttpParams().set('householdId', householdId.toString());
    return this.http.get(`${this.apiUrl}/admin/income-categories`, { headers: this.getHeaders(), params });
  }

  createIncomeCategory(data: any): Observable<any> {
    return this.http.post(`${this.apiUrl}/admin/income-categories`, data, { headers: this.getHeaders() });
  }

  updateIncomeCategory(id: number, data: any): Observable<any> {
    return this.http.put(`${this.apiUrl}/admin/income-categories/${id}`, data, { headers: this.getHeaders() });
  }

  deleteIncomeCategory(id: number): Observable<any> {
    return this.http.delete(`${this.apiUrl}/admin/income-categories/${id}`, { headers: this.getHeaders() });
  }

  reorderIncomeCategories(items: { id: number; sortOrder: number }[]): Observable<any> {
    return this.http.put(`${this.apiUrl}/admin/income-categories/reorder`, { items }, { headers: this.getHeaders() });
  }
}
