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
import { Member } from './Member/Member';
import { Transaction } from './Money/Transaction';
import { Transactions } from './Money/Transactions';
import { Training } from './Training/Training';
import { Trainings } from './Training/Trainings';
import { MemberTokens } from './Member/MemberTokens';
import { Analysis } from './Analysis/Analysis';
import { MembershipPeriod } from './MembershipPeriod/MembershipPeriod';
import { MembershipPeriods } from './MembershipPeriod/MembershipPeriods';
import { MemberMembershipPeriods } from './Member/MemberMembershipPeriods';
import { TransactionsImport } from './MoneyImport/TransactionsImport';
import { createUploadLink } from "apollo-upload-client";
import { createLink } from "apollo-absinthe-upload-link";
import { MembershipPeriodMembers } from './MembershipPeriod/MembershipPeriodMembers';
import { MemberTrainingAttendance } from './Member/MemberTrainingAttendance';



const router = createBrowserRouter([
  {
    path: "/",
    element: <App />,
    // loader: rootLoader,
    children: [
      {
        path: "/",
        element: <Analysis />
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
      }, {
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

const client = new ApolloClient({
  // uri: 'http://localhost:3999/',
  // uri: `${process.env["REACT_APP_ADMIN_URL"]}/api/graphql`,
  cache: new InMemoryCache(),
  link: uploadLink,
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
