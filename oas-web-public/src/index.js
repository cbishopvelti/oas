import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App/App';
import reportWebVitals from './reportWebVitals';
import { RouterProvider, createBrowserRouter } from 'react-router-dom';
import { Home } from './Home/Home';
import { MembershipInfo } from './Members/Info'
import { MembershipForm } from './Members/MembershipForm';
import { ApolloClient, InMemoryCache, ApolloProvider, gql, split, HttpLink } from '@apollo/client';
import { getMainDefinition } from "@apollo/client/utilities";
import { MembershipSuccess } from './Members/MembershipSuccess';
import { Tokens } from './Tokens/Tokens';
import { Credits } from './Credits/Credits';
import { Bookings } from './Bookings/Bookings';
import { Socket as PhoenixSocket } from "phoenix";
import Cookies from "js-cookie";
import * as AbsintheSocket from "@absinthe/socket";
import { createAbsintheSocketLink } from "@absinthe/socket-apollo-link";


const router = createBrowserRouter([
  {
    path: "/",
    element: <App />,
    // loader: rootLoader,'
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
      }, {
        path: "register/success",
        element: <MembershipSuccess />
      }, {
        path: "tokens",
        element: <Tokens />
      }, {
        path: "credits",
        element: <Credits />
      },
      {
        path: "bookings",
        element: <Bookings />
      }
    ],
  },
]);

const httpLink = new HttpLink({
  uri: `${process.env["REACT_APP_PUBLIC_URL"]}/api/graphql`
});
const phoenixSocket = new PhoenixSocket(`${process.env["REACT_APP_SERVER_URL"].replace(/^http/, "ws")}/socket`, {
  reconnectAfterMs: (() => 120_000),
	rejoinAfterMs: (() => 120_000),
  params: () => {
    if (Cookies.get("oas_key")) {
      return { cookie: Cookies.get("oas_key") };
    } else {
      return {};
    }
  }
});
const absintheSocket = AbsintheSocket.create(phoenixSocket);
const subscriptionLink = createAbsintheSocketLink(absintheSocket);

const theLink = split(
  ({ query }) => {
    const definition = getMainDefinition(query);

    const out = !(
      definition.kind === "OperationDefinition" &&
      definition.operation === "subscription"
    );

    return out;
  },
  httpLink,
  subscriptionLink
)

const client = new ApolloClient({
  // uri: `${process.env["REACT_APP_PUBLIC_URL"]}/api/graphql`,
  cache: new InMemoryCache(),
  link: theLink
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
