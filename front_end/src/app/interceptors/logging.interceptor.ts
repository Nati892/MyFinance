import { Injectable } from '@angular/core';
import { HttpInterceptor, HttpRequest, HttpHandler, HttpEvent, HttpResponse, HttpErrorResponse } from '@angular/common/http';
import { Observable, throwError } from 'rxjs';
import { tap, catchError } from 'rxjs/operators';
import { LoggerService } from '../services/logger.service';

@Injectable()
export class LoggingInterceptor implements HttpInterceptor {
  constructor(private logger: LoggerService) {}

  intercept(req: HttpRequest<any>, next: HttpHandler): Observable<HttpEvent<any>> {
    const startTime = Date.now();

    // Skip logging for log batch endpoint to avoid infinite loop
    if (req.url.includes('/logs/batch')) {
      return next.handle(req);
    }

    return next.handle(req).pipe(
      tap(event => {
        if (event instanceof HttpResponse) {
          const duration = Date.now() - startTime;
          this.logger.logApiCall(req.method, req.url, duration, event.status);
        }
      }),
      catchError((error: HttpErrorResponse) => {
        const duration = Date.now() - startTime;
        this.logger.logApiCall(req.method, req.url, duration, error.status);
        this.logger.err('HTTP_ERROR', `${req.method} ${req.url} failed`, {
          status: error.status,
          message: error.message,
          error: error.error
        });
        return throwError(() => error);
      })
    );
  }
}