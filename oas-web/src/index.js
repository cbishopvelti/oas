import React from 'react';
import ReactDOM from 'react-dom/client';
import './index.css';
import App from './App/App';
import reportWebVitals from './reportWebVitals';
import { ApolloClient, InMemoryCache, ApolloProvider, gql, split, from } from '@apollo/client';
import { GraphQLWsLink } from "@apollo/client/link/subscriptions";
import { createClient } from "graphql-ws";
import { getMainDefinition } from "@apollo/client/utilities";
import {
  createBrowserRouter,
  RouterProvider,
} from "react-router-dom";
import { LocalizationProvider } from '@mui/x-date-pickers/LocalizationProvider';
import { AdapterMoment } from '@mui/x-date-pickers/AdapterMoment';
import { Members } from './Member/Members';
import { Member } from './Member/Member';
import { Transaction } from './Money/Transaction';
import { Transactions } from './Money/Transactions';
import { Training } from './Training/Training';
import { Trainings } from './Training/Trainings';
import { MemberTokens } from './Member/MemberTokens';
import { MemberCredits } from './Member/MemberCredits';
import { Analysis } from './Analysis/Analysis';
import { MembershipPeriod } from './MembershipPeriod/MembershipPeriod';
import { MembershipPeriods } from './MembershipPeriod/MembershipPeriods';
import { MemberMembershipPeriods } from './Member/MemberMembershipPeriods';
import { TransactionsImport } from './MoneyImport/TransactionsImport';
import { createUploadLink } from "apollo-upload-client";
import { createLink } from "apollo-absinthe-upload-link";
import { MembershipPeriodMembers } from './MembershipPeriod/MembershipPeriodMembers';
import { MemberTrainingAttendance } from './Member/MemberTrainingAttendance';
import { ConfigTokens } from './Config/ConfigTokens';
import { Gocardless } from './Config/Gocardless';
import { GocardlessRequisition } from './Config/GocardlessRequisition';
import { AnalysisAttendance } from './Analysis/AnalysisAttendance';
import { AnalysisBalance } from './Analysis/AnalysisBalance';
import { Socket as PhoenixSocket } from "phoenix";
import Cookies from "js-cookie";
import * as AbsintheSocket from "@absinthe/socket";
import { createAbsintheSocketLink } from "@absinthe/socket-apollo-link";
import { Venue } from './Venue/Venue';
import { Venues } from './Venue/Venues';
import { Thing } from './Things/Thing';
import { Things } from './Things/Things';


const router = createBrowserRouter([
  {
    path: "/",
    element: <App />,
    // loader: rootLoader,
    children: [
      {
        id: 'analysis',
        path: "/",
        element: <Analysis />
      },
      {
        id: 'analysis-attendance',
        path: "/analysis/attendance",
        element: <AnalysisAttendance />
      },
      {
        id: 'analysis-balance',
        path: "/analysis/balance",
        element: <AnalysisBalance />
      },
      {
        id: "members",
        path: "members",
        element: <Members />
      },
      {
        id: "member",
        path: "member",
        element: <Member />
      }, {
        id: "member-id",
        path: "member/:id",
        element: <Member />
      },
      {
        id: "transaction-id",
        path: "transaction/:id",
        element: <Transaction />
      }, {
        id: "member-transactions",
        path: "member/:member_id/transactions",
        element: <Transactions />
      },
      {
        id: "member-attendance",
        path: "member/:member_id/attendance",
        element: <MemberTrainingAttendance />
      },
      {
        id: "transaction",
        path: "transaction",
        element: <Transaction />
      },
      {
        id: "transactions",
        path: "transactions",
        element: <Transactions />
      },
      {
        id: "import-transactions",
        path: "import-transactions",
        element: <TransactionsImport />
      },
      {
        id: "member-tokens",
        path: "member/:id/tokens",
        element: <MemberTokens />
      },
      {
        id: "member-credits",
        path: "member/:id/credits",
        element: <MemberCredits />
      },
      {
        id: "member-membership-periods",
        path: "member/:member_id/membership-periods",
        element: <MemberMembershipPeriods />
      },
      {
        id: "training-id",
        path: "training/:id",
        element: <Training />
      },
      {
        id: "training",
        path: "training",
        element: <Training />
      },
      {
        id: "trainings",
        path: "trainings",
        element: <Trainings />
      },
      {
        id: "membership-period-id",
        path: "membership-period/:id",
        element: <MembershipPeriod />
      },
      {
        id: "membership-period-members",
        path: "membership-period/:id/members",
        element: <MembershipPeriodMembers />
      },
      {
        id: "membership-period",
        path: "membership-period",
        element: <MembershipPeriod />
      },
      {
        id: "membership-periods",
        path: "membership-periods",
        element: <MembershipPeriods />
      },
      {
        id: "config",
        path: "config",
        element: <ConfigTokens />
      },
      {
        id: "gocardless",
        path: "config/gocardless",
        element: <Gocardless />
      },
      {
        id: "gocardless-requisition",
        path: "config/gocardless/requisition",
        element: <GocardlessRequisition />
      }, {
        id: "venues",
        path: "venues",
        element: <Venues />
      }, {
        id: "venue",
        path: "venue",
        element: <Venue />
      }, {
        id: "venue-id",
        path: "venue/:id",
        element: <Venue />
      }, {
        id: "things",
        path: "things",
        element: <Things />
      }, {
        id: "thing",
        path: "/thing",
        element: <Thing />
      }, {
        id: "thing-id",
        path: "thing/:id",
        element: <Thing />
      }
    ],
  },
]);

// const uploadLink = new createUploadLink({
//   uri: `${process.env["REACT_APP_ADMIN_URL"]}/api/graphql`
// });
const uploadLink = createLink({
  uri: `${process.env["REACT_APP_ADMIN_URL"]}/api/graphql`
});

// Create a standard Phoenix websocket connection. If you need
// to provide additional params, like an authentication token,
// you can configure them in the `params` option.
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
// Wrap the Phoenix socket in an AbsintheSocket.
const absintheSocket = AbsintheSocket.create(phoenixSocket);
// Create an Apollo link from the AbsintheSocket instance.
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
  uploadLink,
  subscriptionLink
)


const client = new ApolloClient({
  // uri: 'http://localhost:3999/',
  // uri: `${process.env["REACT_APP_ADMIN_URL"]}/api/graphql`,
  cache: new InMemoryCache(),
  // link: uploadLink,
  link: theLink
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
