import { useEffect } from 'react';
import { Members } from '../Member/Members';
import { gql, useQuery } from '@apollo/client';
import { MenuList, MenuItem, ListItemText, Divider, ListItem } from '@mui/material';
import { get } from 'lodash';
import {
  NavLink
} from "react-router-dom";
import {
  MemberLink,
  TrainingsLink,
  TransactionLink,
  MembershipPeriodLink
} from './Links';
import { useTheme } from '@mui/material/styles';
import useMediaQuery from '@mui/material/useMediaQuery';


export const AppMenu = ({ setOpen }) => {
  const theme = useTheme();
  const matches = useMediaQuery(theme.breakpoints.down('md'));

  const onClick = () => {
    if (matches) {
      setOpen(false)
    }
  }

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

  return <MenuList>
    <MenuItem onClick={onClick} component={NavLink} end to={`/member`}>
      <ListItemText>New Member</ListItemText>
    </MenuItem>
    <MenuItem onClick={onClick} component={MemberLink} to={`/members`}>
      <ListItemText>Members</ListItemText>
    </MenuItem>
    <MenuItem onClick={onClick}
      component={NavLink}
      to={`/transaction`}
      end
      >
      <ListItemText>New Transaction</ListItemText>
    </MenuItem>
    <MenuItem onClick={onClick}
      component={NavLink}
      to={`/import-transactions`}
      end >
        <ListItemText>Import Transactions</ListItemText>
      </MenuItem>
    <MenuItem onClick={onClick} component={TransactionLink} to={`/transactions`}>
      <ListItemText>Transactions</ListItemText>
    </MenuItem>
    <MenuItem onClick={onClick} component={NavLink} end to={`/training`}>
      <ListItemText>New Training</ListItemText>
    </MenuItem>
    <MenuItem onClick={onClick} component={TrainingsLink} to={`/trainings`}>
      <ListItemText>Trainings</ListItemText>
    </MenuItem>
    <MenuItem onClick={onClick} component={NavLink} end to="/">
      <ListItemText>Analysis</ListItemText>
    </MenuItem>
    <MenuItem onClick={onClick} component={NavLink} end to="/membership-period">
      New Membership Period
    </MenuItem>
    <MenuItem onClick={onClick} component={MembershipPeriodLink} to="/membership-periods">
      Membership Periods
    </MenuItem>

    <Divider />
    {!!get(data, "user") && [<ListItem key="1">
      <ListItemText>
        {get(data, "user.name")}
      </ListItemText>
    </ListItem>,
    <MenuItem onClick={onClick} key="2">
      <a
        style={{color: 'inherit', textDecoration: 'none'}}
        href={`${process.env.REACT_APP_SERVER_URL}${get(data, "user.logout_link")}`}
        data-method="delete"
        rel="nofollow"
        >
        Logout
      </a>
    </MenuItem>]}
    {!get(data, "user") && <MenuItem onClick={onClick}>
      <a
        style={{color: 'inherit', textDecoration: 'none'}}
        href={`${process.env.REACT_APP_SERVER_URL}/members/log_in`}>
        Login
      </a>
    </MenuItem>}
  </MenuList>
}