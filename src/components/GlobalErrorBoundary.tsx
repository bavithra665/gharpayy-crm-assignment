import React, { Component, ErrorInfo, ReactNode } from 'react';
import { AlertCircle } from 'lucide-react';
import { Button } from '@/components/ui/button';

interface Props {
  children?: ReactNode;
}

interface State {
  hasError: boolean;
  error: Error | null;
}

export class GlobalErrorBoundary extends Component<Props, State> {
  public state: State = {
    hasError: false,
    error: null
  };

  public static getDerivedStateFromError(error: Error): State {
    return { hasError: true, error };
  }

  public componentDidCatch(error: Error, errorInfo: ErrorInfo) {
    console.error('Uncaught error:', error, errorInfo);
    // Here we could also send to Sentry manually if needed
    // import * as Sentry from "@sentry/react";
    // Sentry.captureException(error);
  }

  public render() {
    if (this.state.hasError) {
      return (
        <div className="flex h-screen w-full items-center justify-center bg-gray-50 flex-col gap-4 p-8">
          <AlertCircle className="h-16 w-16 text-red-500" />
          <h1 className="text-2xl font-bold text-gray-900">Oops, something went wrong!</h1>
          <p className="text-gray-600 max-w-md text-center">
            {this.state.error?.message || "An unexpected error occurred in the application."}
          </p>
          <Button onClick={() => window.location.reload()} className="mt-4">
            Reload Application
          </Button>
        </div>
      );
    }

    return this.props.children;
  }
}
