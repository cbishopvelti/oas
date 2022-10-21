import logo from './logo.svg';
import './App.css';
import { gql, useQuery } from '@apollo/client';
import { Members } from '../Member/Members';
import { MenuList, MenuItem, ListItemText, Divider, ListItem } from '@mui/material';
import {
  Link,
  Outlet,
  NavLink
} from "react-router-dom";
import {
  MemberLink,
  TrainingsLink,
  TransactionLink
} from './Links';
import { useEffect } from 'react';
import { get } from 'lodash';

function App() {
  const { data, refetch } = useQuery(gql`
  query {
    user {
      name,
      logout_link
    }
  }`)
  useEffect(() => {
    refetch();
  }, [])

  return (
    <div className="App">
      <div>
        <MenuList>
          <MenuItem component={NavLink} to={`/new-member`}>
            <ListItemText>New Member</ListItemText>
          </MenuItem>
          <MenuItem component={MemberLink} to={`/members`}>
            <ListItemText>Members</ListItemText>
          </MenuItem>
          <MenuItem
            component={NavLink}
            to={`/transaction`}
            end
            >
            <ListItemText>New Transaction</ListItemText>
          </MenuItem>
          <MenuItem component={TransactionLink} to={`/transactions`}>
            <ListItemText>Transactions</ListItemText>
          </MenuItem>
          <MenuItem component={NavLink} end to={`/training`}>
            <ListItemText>New Training</ListItemText>
          </MenuItem>
          <MenuItem component={TrainingsLink} to={`/trainings`}>
            <ListItemText>Trainings</ListItemText>
          </MenuItem>
          <MenuItem component={NavLink} end to="/">
            <ListItemText>Analysis</ListItemText>
          </MenuItem>
          <Divider />
          <ListItem>
            <ListItemText>
              {get(data, "user.name")}
            </ListItemText>
          </ListItem>
          <MenuItem>
            <a
              style={{color: 'inherit', textDecoration: 'none'}}
              href={`${process.env.REACT_APP_SERVER_URL}${get(data, "user.logout_link")}`}
              data-method="delete"
              rel="nofollow"
              >
              Logout
            </a>
          </MenuItem>
        </MenuList>
      </div>
      <div className="content">
        <Outlet />
      </div>
    </div>
  );
}

export default App;
