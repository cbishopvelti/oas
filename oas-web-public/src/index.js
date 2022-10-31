import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App/App';
import reportWebVitals from './reportWebVitals';
import { RouterProvider, createBrowserRouter } from 'react-router-dom';
import { Home } from './Home/Home';
import { MembershipInfo } from './Members/Info'
import { MembershipForm } from './Members/MembershipForm';
import { ApolloClient, InMemoryCache, ApolloProvider, gql } from '@apollo/client';


const router = createBrowserRouter([
  {
    path: "/",
    element: <App />,
    // loader: rootLoader,
    children: [
      {
        path: "/",
        element: <Home />
      },
      {
        path: "membership-info",
        element: <MembershipInfo />
      }, {
        path: "register",
        element: <MembershipForm />
      }
    ],
  },
]);

const client = new ApolloClient({
  // uri: 'http://localhost:3998/',
  uri: `${process.env["REACT_APP_PUBLIC_URL"]}/api/graphql`,
  cache: new InMemoryCache(),
});

const root = ReactDOM.createRoot(document.getElementById('root'));
root.render(
  <React.StrictMode>
    <ApolloProvider client={client}>
      <RouterProvider router={router}>
        <App />
      </RouterProvider>
    </ApolloProvider>
  </React.StrictMode>
);

// If you want to start measuring performance in your app, pass a function
// to log results (for example: reportWebVitals(console.log))
// or send to an analytics endpoint. Learn more: https://bit.ly/CRA-vitals
reportWebVitals();
