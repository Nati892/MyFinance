import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AuthService } from './auth.service';
import { getApiUrl } from '../utils/get-base-address';

@Injectable({
    providedIn: 'root'
})
export class AppUsersService {
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

    getAppUsers(page: number, limit: number, search?: string): Observable<any> {
        let params = new HttpParams()
            .set('page', page.toString())
            .set('limit', limit.toString());

        if (search && search.trim()) {
            params = params.set('search', search.trim());
        }

        return this.http.get(`${this.apiUrl}/app-users`, {
            headers: this.getHeaders(),
            params
        });
    }

    getAppUser(id: number): Observable<any> {
        return this.http.get(`${this.apiUrl}/app-users/${id}`, {
            headers: this.getHeaders()
        });
    }

    createAppUser(data: { username: string; password: string }): Observable<any> {
        return this.http.post(`${this.apiUrl}/app-users`, data, {
            headers: this.getHeaders()
        });
    }

    updateAppUser(id: number, data: { username?: string; isActive?: boolean; isDeveloper?: boolean }): Observable<any> {
        return this.http.put(`${this.apiUrl}/app-users/${id}`, data, {
            headers: this.getHeaders()
        });
    }

    resetPassword(id: number, newPassword: string): Observable<any> {
        return this.http.put(`${this.apiUrl}/app-users/${id}/password`, { newPassword }, {
            headers: this.getHeaders()
        });
    }

    deleteAppUser(id: number): Observable<any> {
        return this.http.delete(`${this.apiUrl}/app-users/${id}`, {
            headers: this.getHeaders()
        });
    }
}
