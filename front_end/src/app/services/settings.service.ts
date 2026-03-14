import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders, HttpParams } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AuthService } from './auth.service';
import { getBaseAddress } from '../utils/get-base-address';

@Injectable({
    providedIn: 'root'
})
export class SettingsService {
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

    getSettings(filters?: any): Observable<any> {
        let params = new HttpParams();
        if (filters) {
            Object.keys(filters).forEach(key => {
                if (filters[key] !== undefined && filters[key] !== '') {
                    params = params.set(key, filters[key]);
                }
            });
        }

        return this.http.get(`${this.apiUrl}/settings`, { 
            headers: this.getHeaders(), 
            params 
        });
    }

    getSetting(id: number): Observable<any> {
        return this.http.get(`${this.apiUrl}/settings/${id}`, { 
            headers: this.getHeaders() 
        });
    }

    createSetting(setting: any): Observable<any> {
        return this.http.post(`${this.apiUrl}/settings`, setting, { 
            headers: this.getHeaders() 
        });
    }

    updateSetting(id: number, updates: any): Observable<any> {
        return this.http.put(`${this.apiUrl}/settings/${id}`, updates, { 
            headers: this.getHeaders() 
        });
    }

    deleteSetting(id: number): Observable<any> {
        return this.http.delete(`${this.apiUrl}/settings/${id}`, { 
            headers: this.getHeaders() 
        });
    }

    getConfigSettings(): Observable<any> {
        return this.http.get(`${this.apiUrl}/settings/config`, { 
            headers: this.getHeaders() 
        });
    }

    bulkUpdateSettings(settings: any[]): Observable<any> {
        return this.http.post(`${this.apiUrl}/settings/bulk-update`, { settings }, { 
            headers: this.getHeaders() 
        });
    }
}