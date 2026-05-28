import React from 'react';
export class ErrorBoundary extends React.Component {
  constructor(props) {
    super(props);
    this.state = { hasError: false, error: null };
  }
  static getDerivedStateFromError(error) {
    return { hasError: true, error };
  }
  componentDidCatch(error, errorInfo) {
    if (window.electronAPI && window.electronAPI.showErrorBox) {
      window.electronAPI.showErrorBox('React Crash', `${error}\n${errorInfo.componentStack}`);
    }
  }
  render() {
    if (this.state.hasError) {
      return <div style={{color:'red', background:'white', position:'absolute', zIndex:9999, top:0, left:0, padding: 20}}><h1>App Crashed!</h1><pre>{this.state.error && this.state.error.toString()}</pre></div>;
    }
    return this.props.children;
  }
}
