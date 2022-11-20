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


export const MenuMembershipPeriod = () => {
  
  const matches = useMatches();


  const membershipPeriodIds = ["membership-period-id", "membership-periods", "membership-period-members", "member-membership-periods"];
  const newMembershipPeriodIds = ['membership-period']
  const allIds = [...membershipPeriodIds, ...newMembershipPeriodIds];
  const forceIds = [...newMembershipPeriodIds];

  const active = some(matches, ({id}) => includes(allIds, id))
  const forceActive = some(matches, ({id}) => includes(forceIds, id))
  const [open, setOpen] = useState(active);

  useEffect(() => {
    if (!forceActive) {
      setOpen(false);
    } else {
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
    <MenuItem component={CustomLink(membershipPeriodIds)} end to={`/membership-periods`}>
      <ListItemText>Membership Periods</ListItemText>
      <IconButton onClick={handleOpen}>
        {
          open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />
        }
      </IconButton>
    </MenuItem>
    <Collapse in={open} timeout="auto">
      <MenuItem sx={{ml: 2}} component={CustomLink(newMembershipPeriodIds)} end to={`/membership-period`}>
        <ListItemText>New Membership Period</ListItemText>
      </MenuItem>
    </Collapse>
  </>
}