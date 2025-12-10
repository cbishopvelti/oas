import { MenuList, MenuItem, Divider, ListItem, ListItemText, Collapse, IconButton } from '@mui/material';
import { useEffect, useState } from 'react';
import {
  NavLink
} from "react-router-dom";
import { CustomLink } from './Links';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp';
import { includes, some } from 'lodash';
import { useMatches } from 'react-router-dom';


export const MenuTransaction = () => {

  const matches = useMatches();

  const transactionIds = ["transaction-id", "transactions", "member-transactions"];
  const newTransactionIds = ['transaction']
  const importTransactionIds = ['import-transactions']
  const pendingTransactions = ["pending-transactions"]
  const allIds = [...transactionIds, ...newTransactionIds, ...importTransactionIds, ...pendingTransactions];
  const forceIds = [...newTransactionIds, ...importTransactionIds, ...pendingTransactions];

  const active = some(matches, ({id}) => includes(allIds, id))
  const forceActive = some(matches, ({id}) => includes(forceIds, id));
  const [open, setOpen] = useState(active);

  useEffect(() => {
    if (!forceActive && !active) {
      setOpen(false);
    } else if (forceActive) {
      setOpen(true);
    }
  }, matches);

  const handleOpen = (event) => {
    event.stopPropagation();
    event.preventDefault();

    if (forceActive) {
      return;
    }

    setOpen(!open)

    return false;
  }

  return <>
    <MenuItem
      component={CustomLink(transactionIds)} end to={`/transactions`}>
      <ListItemText>Transactions</ListItemText>
      <IconButton onClick={handleOpen}>
        {
          open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />
        }
      </IconButton>
    </MenuItem>
    <Collapse in={open} timeout="auto">
      <MenuItem
        sx={{ml:2}}
        component={NavLink}
        to={`/transaction`}
        end
        >
        <ListItemText>New Transaction</ListItemText>
      </MenuItem>
      {/* <MenuItem
        sx={{ml: 2}}
        component={NavLink}
        to={`/import-transactions`}
        end >
        <ListItemText>Import Transactions</ListItemText>
      </MenuItem>*/}
      <MenuItem
        sx={{ml: 2}}
        component={NavLink}
        to='/transactions/pending'
        end
      >
        <ListItemText>Pending Transactions</ListItemText>
      </MenuItem>
    </Collapse>
  </>
}
