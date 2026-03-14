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
}
