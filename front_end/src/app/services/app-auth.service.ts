import { Injectable } from '@angular/core';
import { HttpClient } from '@angular/common/http';
import { BehaviorSubject, Observable, of } from 'rxjs';
import { tap, map, catchError } from 'rxjs/operators';
import { Router } from '@angular/router';
import { getBaseAddress } from '../utils/get-base-address';

export interface AppUser {
  id: number;
  username: string;
  isActive: boolean;
  lastLogin: string;
  households: { householdId: number; householdName: string; role: string }[];
}

@Injectable({ providedIn: 'root' })
export class AppAuthService {
  private apiUrl = getBaseAddress() + '/api/app/auth';
  private currentUserSubject = new BehaviorSubject<AppUser | null>(null);
  currentUser$ = this.currentUserSubject.asObservable();

  constructor(
    private http: HttpClient,
    private router: Router
  ) {}

  signIn(username: string, password: string): Observable<any> {
    return this.http.post<any>(`${this.apiUrl}/signin`, { username, password }).pipe(
      tap(response => {
        localStorage.setItem('app_access_token', response.accessToken);
        localStorage.setItem('app_refresh_token', response.refreshToken);
        localStorage.setItem('app_user_id', String(response.user.id));
        localStorage.setItem('app_token_expiry', String(Date.now() + 3600000));
        this.currentUserSubject.next(response.user);
      })
    );
  }

  refreshToken(): Observable<any> {
    const refreshToken = localStorage.getItem('app_refresh_token');
    const userId = localStorage.getItem('app_user_id');
    return this.http.post<any>(`${this.apiUrl}/refresh`, { refreshToken, userId }).pipe(
      tap(response => {
        localStorage.setItem('app_access_token', response.accessToken);
        localStorage.setItem('app_token_expiry', String(Date.now() + 3600000));
      })
    );
  }

  getProfile(): Observable<any> {
    return this.http.get<any>(`${this.apiUrl}/profile`);
  }

  signOut(): void {
    localStorage.removeItem('app_access_token');
    localStorage.removeItem('app_refresh_token');
    localStorage.removeItem('app_user_id');
    localStorage.removeItem('app_token_expiry');
    this.currentUserSubject.next(null);
    this.router.navigate(['/app/login']);
  }

  isLoggedIn(): boolean {
    const token = localStorage.getItem('app_access_token');
    const expiry = localStorage.getItem('app_token_expiry');
    if (!token || !expiry) {
      return false;
    }
    return Date.now() < Number(expiry);
  }

  getToken(): string | null {
    return localStorage.getItem('app_access_token');
  }

  getCurrentUser(): AppUser | null {
    return this.currentUserSubject.value;
  }

  loadCurrentUser(): void {
    const token = localStorage.getItem('app_access_token');
    const expiry = localStorage.getItem('app_token_expiry');
    if (token && expiry && Date.now() < Number(expiry)) {
      this.getProfile().pipe(
        catchError(() => of(null))
      ).subscribe(user => {
        if (user) {
          this.currentUserSubject.next(user);
        }
      });
    }
  }

  checkAndRefresh(): Observable<boolean> {
    const token = localStorage.getItem('app_access_token');
    const expiry = localStorage.getItem('app_token_expiry');

    if (!token || !expiry) {
      return of(false);
    }

    const expiryMs = Number(expiry);
    const fiveMinutesMs = 5 * 60 * 1000;

    if (Date.now() < expiryMs - fiveMinutesMs) {
      return of(true);
    }

    return this.refreshToken().pipe(
      map(() => true as boolean),
      catchError(() => {
        localStorage.removeItem('app_access_token');
        localStorage.removeItem('app_refresh_token');
        localStorage.removeItem('app_user_id');
        localStorage.removeItem('app_token_expiry');
        this.currentUserSubject.next(null);
        return of(false);
      })
    );
  }
}
