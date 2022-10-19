import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App/App';
import reportWebVitals from './reportWebVitals';
import { ApolloClient, InMemoryCache, ApolloProvider, gql } from '@apollo/client';
import {
  createBrowserRouter,
  RouterProvider,
} from "react-router-dom";
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterMoment } from '@mui/x-date-pickers/AdapterMoment';

import { Members } from './Member/Members';
import { NewMember } from './Member/NewMember';
import { Transaction } from './Money/Transaction';
import { Transactions } from './Money/Transactions';
import { Tokens } from './Member/Tokens';
import { Training } from './Training/Training';
import { Trainings } from './Training/Trainings';


const router = createBrowserRouter([
  {
    path: "/",
    element: <App />,
    // loader: rootLoader,
    children: [
      {
        path: "/",
        element: <div>Home</div>
      },
      {
        id: "members",
        path: "members",
        element: <Members />
      },
      {
        path: "new-member",
        element: <NewMember />
      }, {
        id: "member-id",
        path: "member/:id",
        element: <NewMember />
      },
      {
        path: "transaction",
        element: <Transaction />
      },
      {
        path: "transactions",
        element: <Transactions />
      },
      {
        id: "member-tokens",
        path: "member/:id/tokens",
        element: <Tokens />
      }, {
        id: "training-id",
        path: "training/:id",
        element: <Training />
      },
      {
        path: "training",
        element: <Training />
      },
      {
        id: "trainings",
        path: "trainings",
        element: <Trainings />
      }
    ],
  },
]);



const client = new ApolloClient({
  // uri: 'http://localhost:3999/',
  uri: "http://localhost:3999/api/graphql",
  cache: new InMemoryCache(),
});

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <LocalizationProvider dateAdapter={AdapterMoment}>
      <ApolloProvider client={client}>
        <RouterProvider router={router}>
          <App />
        </RouterProvider>
      </ApolloProvider>
    </LocalizationProvider>
  </React.StrictMode>
);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
