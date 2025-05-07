# LeakLens Frontend

This is the frontend application for LeakLens, a secure credential leak checker that uses Google's Password Check API.

## Setup Instructions

### Prerequisites

- Node.js 16.x or higher
- npm or yarn

### Installation

1. Install dependencies:

```bash
npm install
# or
yarn install
```

2. Create an `.env.local` file in the root of the webapp directory with the following content:

```
# Environment variables for the LeakLens frontend

# API URL - location of the backend API server
NEXT_PUBLIC_API_URL=http://localhost:3000
```

Replace the URL with your backend API server URL if it's hosted elsewhere.

### Development

Run the development server:

```bash
npm run dev
# or
yarn dev
```

The application will be available at [http://localhost:3001](http://localhost:3001).

### Building for Production

Build the application for production:

```bash
npm run build
# or
yarn build
```

Start the production server:

```bash
npm run start
# or
yarn start
```

## Key Features

- **Single Credential Check**: Check individual username/password combinations against known data breaches.
- **Batch Credential Check**: Upload a file with multiple credentials to check them all at once.
- **Secure Processing**: All passwords are encrypted client-side using commutative elliptic curve cryptography.
- **API Status Monitoring**: Real-time monitoring of the backend API and Google API connection status.

## Project Structure

- `app/`: Next.js app router pages and layout components
- `components/`: Reusable UI components
- `hooks/`: Custom React hooks, including API query hooks
- `lib/`: Utility functions and API client code
- `public/`: Static assets
- `styles/`: Global styles

## Architecture

The frontend uses:

- **Next.js**: React framework with app router
- **React Query**: For efficient data fetching, caching, and state management
- **shadcn/ui**: UI component library
- **Tailwind CSS**: For styling
- **TypeScript**: For type safety

## Integration with Backend

The frontend communicates with the backend API through the functions defined in `lib/api.ts`. These functions are wrapped in React Query hooks in `hooks/use-api-queries.ts` to provide data fetching, caching, and state management capabilities.

Key API endpoints:
- `GET /api/v1/status`: Get backend and Google API status
- `POST /api/v1/check/single`: Check a single credential
- `POST /api/v1/check/batch`: Upload and check multiple credentials
- `GET /api/v1/check/batch/:jobId/status`: Get status and results of a batch job 