import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App from './App.jsx'
import { ErrorBoundary } from './ErrorBoundary.jsx'
window.onerror = function(message, source, lineno, colno, error) {
  if (window.electron && window.electron.ipcRenderer) {
    window.electron.ipcRenderer.send('crash-log', `Global Error: ${message} at ${source}:${lineno}:${colno}\\n${error && error.stack}`);
  }
};

window.addEventListener('unhandledrejection', function(event) {
  if (window.electron && window.electron.ipcRenderer) {
    window.electron.ipcRenderer.send('crash-log', `Unhandled Promise Rejection: ${event.reason && event.reason.stack ? event.reason.stack : event.reason}`);
  }
});

createRoot(document.getElementById('root')).render(
  <StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </StrictMode>,
)
