import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AppAuthService } from './app-auth.service';
import { getApiUrl } from '../utils/get-base-address';

@Injectable({ providedIn: 'root' })
export class TransactionService {
  private apiUrl = getApiUrl();

  constructor(
    private http: HttpClient,
    private appAuthService: AppAuthService
  ) {}

  private getHeaders(): HttpHeaders {
    const token = this.appAuthService.getToken();
    return new HttpHeaders({
      'Content-Type': 'application/json',
      Authorization: `Bearer ${token}`,
    });
  }

  /**
   * GET /api/app/expenses?householdId=&view=&periodOffset=&weekNumber=&date=&categoryId=
   */
  getExpenses(params: {
    householdId: number;
    view: string;
    periodOffset: number;
    weekNumber?: number;
    date?: string;
    categoryId?: number | null;
  }): Observable<{ success: boolean; expenses: any[]; period: any; totalAmount: number }> {
    let httpParams = new HttpParams()
      .set('householdId', params.householdId.toString())
      .set('view', params.view)
      .set('periodOffset', params.periodOffset.toString());

    if (params.weekNumber != null) {
      httpParams = httpParams.set('weekNumber', params.weekNumber.toString());
    }
    if (params.date != null) {
      httpParams = httpParams.set('date', params.date);
    }
    if (params.categoryId != null) {
      httpParams = httpParams.set('categoryId', params.categoryId.toString());
    }

    return this.http.get<{ success: boolean; expenses: any[]; period: any; totalAmount: number }>(
      `${this.apiUrl}/app/expenses`,
      { headers: this.getHeaders(), params: httpParams }
    );
  }

  /**
   * POST /api/app/expenses
   */
  createExpense(data: {
    amount: number;
    dateTime: string;
    description?: string;
    note?: string;
    paymentMethod: string;
    expenseCategoryId: number;
    householdId: number;
  }): Observable<any> {
    return this.http.post<any>(
      `${this.apiUrl}/app/expenses`,
      data,
      { headers: this.getHeaders() }
    );
  }

  /**
   * PUT /api/app/expenses/:id
   */
  updateExpense(
    id: number,
    data: Partial<{
      amount: number;
      dateTime: string;
      description: string;
      note: string;
      paymentMethod: string;
      expenseCategoryId: number;
    }>
  ): Observable<any> {
    return this.http.put<any>(
      `${this.apiUrl}/app/expenses/${id}`,
      data,
      { headers: this.getHeaders() }
    );
  }

  /**
   * DELETE /api/app/expenses/:id
   */
  deleteExpense(id: number): Observable<any> {
    return this.http.delete<any>(
      `${this.apiUrl}/app/expenses/${id}`,
      { headers: this.getHeaders() }
    );
  }

  // ─── Incomes ─────────────────────────────────────────────────────────────────

  /**
   * GET /api/app/incomes?householdId=&view=&periodOffset=&weekNumber=&date=&categoryId=
   */
  getIncomes(params: {
    householdId: number;
    view: string;
    periodOffset: number;
    weekNumber?: number;
    date?: string;
    categoryId?: number | null;
  }): Observable<{ success: boolean; incomes: any[]; period: any; totalAmount: number }> {
    let httpParams = new HttpParams()
      .set('householdId', params.householdId.toString())
      .set('view', params.view)
      .set('periodOffset', params.periodOffset.toString());

    if (params.weekNumber != null) {
      httpParams = httpParams.set('weekNumber', params.weekNumber.toString());
    }
    if (params.date != null) {
      httpParams = httpParams.set('date', params.date);
    }
    if (params.categoryId != null) {
      httpParams = httpParams.set('categoryId', params.categoryId.toString());
    }

    return this.http.get<{ success: boolean; incomes: any[]; period: any; totalAmount: number }>(
      `${this.apiUrl}/app/incomes`,
      { headers: this.getHeaders(), params: httpParams }
    );
  }

  /**
   * POST /api/app/incomes
   */
  createIncome(data: {
    amount: number;
    dateTime: string;
    description?: string;
    note?: string;
    paymentMethod: string;
    incomeCategoryId: number;
    householdId: number;
  }): Observable<any> {
    return this.http.post<any>(
      `${this.apiUrl}/app/incomes`,
      data,
      { headers: this.getHeaders() }
    );
  }

  /**
   * PUT /api/app/incomes/:id
   */
  updateIncome(id: number, data: any): Observable<any> {
    return this.http.put<any>(
      `${this.apiUrl}/app/incomes/${id}`,
      data,
      { headers: this.getHeaders() }
    );
  }

  /**
   * DELETE /api/app/incomes/:id
   */
  deleteIncome(id: number): Observable<any> {
    return this.http.delete<any>(
      `${this.apiUrl}/app/incomes/${id}`,
      { headers: this.getHeaders() }
    );
  }
}
