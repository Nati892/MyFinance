import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { map } from 'rxjs/operators';
import { AppAuthService } from './app-auth.service';
import { getApiUrl } from '../utils/get-base-address';

export interface MonthBudgetRow {
  id: number;
  name: string;
  nameHe?: string | null;
  icon: string;
  color: string;
  baseBudget: number | null;
  override: number | null;
  effectiveBudget: number | null;
  spent: number;
  result: number | null; // spent - effectiveBudget
}

export interface WeekSpend {
  weekLabel: string;
  total: number;
}

export interface MonthSpend {
  label: string;
  total: number;
}

@Injectable({ providedIn: 'root' })
export class BudgetService {
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
   * GET /api/app/budget/month?householdId=X&year=Y&month=M
   */
  getMonthBudget(householdId: number, year: number, month: number): Observable<MonthBudgetRow[]> {
    const params = new HttpParams()
      .set('householdId', householdId.toString())
      .set('year', year.toString())
      .set('month', month.toString());
    return this.http.get<any>(
      `${this.apiUrl}/app/budget/month`,
      { headers: this.getHeaders(), params }
    ).pipe(map(res => res.categories ?? []));
  }

  /**
   * PUT /api/app/budget/base
   * body: { expenseCategoryId, householdId, amount }
   */
  setBaseBudget(expenseCategoryId: number, householdId: number, amount: number): Observable<any> {
    return this.http.put(
      `${this.apiUrl}/app/budget/base`,
      { expenseCategoryId, householdId, amount },
      { headers: this.getHeaders() }
    );
  }

  /**
   * PUT /api/app/budget/override
   * body: { expenseCategoryId, householdId, year, month, amount }
   */
  overrideBudget(
    expenseCategoryId: number,
    householdId: number,
    year: number,
    month: number,
    amount: number
  ): Observable<any> {
    return this.http.put(
      `${this.apiUrl}/app/budget/override`,
      { expenseCategoryId, householdId, year, month, amount },
      { headers: this.getHeaders() }
    );
  }

  /**
   * GET /api/app/budget/by-week
   */
  getByWeek(
    householdId: number,
    year: number,
    month: number,
    expenseCategoryId?: number | null
  ): Observable<WeekSpend[]> {
    let params = new HttpParams()
      .set('householdId', householdId.toString())
      .set('year', year.toString())
      .set('month', month.toString());
    if (expenseCategoryId != null) {
      params = params.set('expenseCategoryId', expenseCategoryId.toString());
    }
    return this.http.get<any>(
      `${this.apiUrl}/app/budget/by-week`,
      { headers: this.getHeaders(), params }
    ).pipe(map(res => res.weeks ?? []));
  }

  /**
   * GET /api/app/budget/by-month
   */
  getByMonth(
    householdId: number,
    year: number,
    startMonth: number,
    endMonth: number,
    expenseCategoryId?: number | null
  ): Observable<MonthSpend[]> {
    let params = new HttpParams()
      .set('householdId', householdId.toString())
      .set('year', year.toString())
      .set('startMonth', startMonth.toString())
      .set('endMonth', endMonth.toString());
    if (expenseCategoryId != null) {
      params = params.set('expenseCategoryId', expenseCategoryId.toString());
    }
    return this.http.get<any>(
      `${this.apiUrl}/app/budget/by-month`,
      { headers: this.getHeaders(), params }
    ).pipe(map(res => res.months ?? []));
  }
}
