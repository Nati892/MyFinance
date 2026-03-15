import { Injectable } from '@angular/core';
import { HttpInterceptor, HttpRequest, HttpHandler, HttpEvent } from '@angular/common/http';
import { Observable } from 'rxjs';

@Injectable()
export class AppAuthInterceptor implements HttpInterceptor {
  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    // Only add auth header for app API routes, not sign-in or refresh
    if (
      req.url.includes('/api/app/') &&
      !req.url.includes('/api/app/auth/signin') &&
      !req.url.includes('/api/app/auth/refresh')
    ) {
      const token = localStorage.getItem('app_access_token');
      if (token) {
        req = req.clone({
          setHeaders: { Authorization: `Bearer ${token}` },
        });
      }
    }

    return next.handle(req);
  }
}
