import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AppAuthService } from './app-auth.service';
import { getApiUrl } from '../utils/get-base-address';
import { Category } from '../components/category-sidebar/category-sidebar.component';

export interface CategoryListResponse {
  success: boolean;
  categories: Category[];
}

@Injectable({ providedIn: 'root' })
export class CategoryService {
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
   * GET /api/app/expense-categories?householdId={id}
   */
  getExpenseCategories(householdId: number): Observable<CategoryListResponse> {
    const params = new HttpParams().set('householdId', householdId.toString());
    return this.http.get<CategoryListResponse>(
      `${this.apiUrl}/app/expense-categories`,
      { headers: this.getHeaders(), params }
    );
  }

  /**
   * GET /api/app/income-categories?householdId={id}
   */
  getIncomeCategories(householdId: number): Observable<CategoryListResponse> {
    const params = new HttpParams().set('householdId', householdId.toString());
    return this.http.get<CategoryListResponse>(
      `${this.apiUrl}/app/income-categories`,
      { headers: this.getHeaders(), params }
    );
  }

  /**
   * PUT /api/app/expense-categories/:id/budget
   */
  updateExpenseCategoryBudget(
    id: number,
    monthlyBudget: number | null
  ): Observable<any> {
    return this.http.put(
      `${this.apiUrl}/app/expense-categories/${id}/budget`,
      { monthlyBudget },
      { headers: this.getHeaders() }
    );
  }

  /**
   * POST /api/app/expense-categories
   */
  createExpenseCategory(data: { name: string; icon: string; color: string; monthlyBudget?: number | null; householdId: number }): Observable<any> {
    return this.http.post(
      `${this.apiUrl}/app/expense-categories`,
      data,
      { headers: this.getHeaders() }
    );
  }

  /**
   * POST /api/app/income-categories
   */
  createIncomeCategory(data: { name: string; icon: string; color: string; householdId: number }): Observable<any> {
    return this.http.post(
      `${this.apiUrl}/app/income-categories`,
      data,
      { headers: this.getHeaders() }
    );
  }

  /**
   * GET /api/app/expense-categories/favorites?householdId={id}
   */
  getExpenseFavorites(householdId: number): Observable<{ success: boolean; favorites: Category[] }> {
    const params = new HttpParams().set('householdId', householdId.toString());
    return this.http.get<any>(
      `${this.apiUrl}/app/expense-categories/favorites`,
      { headers: this.getHeaders(), params }
    );
  }
}
