import { StrictMode } from 'react'
import { createRoot } from 'react-dom/client'
import './index.css'
import App, { ErrorBoundary } from './App.jsx'

// Indlæsningsskærmen fra index.html har gjort sit nu. createRoot rydder
// selv beholderen, men den ryddes her, så rækkefølgen ikke afhænger af det.
const rod = document.getElementById('root')
document.getElementById('boot')?.remove()

// Fejlgrænsen ligger uden om App, så den også fanger en fejl i App selv.
createRoot(rod).render(
  <StrictMode>
    <ErrorBoundary>
      <App />
    </ErrorBoundary>
  </StrictMode>,
)
