import { Injectable } from '@angular/core';
import { HttpClient, HttpHeaders } from '@angular/common/http';
import { Observable } from 'rxjs';
import { AuthService } from './auth.service';
import { getApiUrl } from '../utils/get-base-address';

@Injectable({
    providedIn: 'root'
})
export class ApkManagementService {
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

    getLatest(): Observable<any> {
        return this.http.get(`${this.apiUrl}/apk/latest`, {
            headers: this.getHeaders()
        });
    }
}
