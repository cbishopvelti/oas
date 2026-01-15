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

export const MenuAnalysis = () => {

  const matches = useMatches();


  const ids = ["analysis"];
  const analysisAttendanceIds = ['analysis-attendance']
  const analysisBalanceIds = ['analysis-balance']
  const analysisAnnualIds = ['analysis-annual']
  const allIds = [...ids, ...analysisAttendanceIds, ...analysisBalanceIds, ...analysisAnnualIds];
  const forceIds = [...analysisAttendanceIds, ...analysisBalanceIds, ...analysisAnnualIds];

  const active = some(matches, ({id}) => includes(allIds, id))
  const forceActive = some(matches, ({id}) => includes(forceIds, id))

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
    <MenuItem component={CustomLink(ids)} end to={`/`}>
      <ListItemText>Analysis</ListItemText>
      <IconButton onClick={handleOpen}>
        {
          open ? <KeyboardArrowUpIcon /> : <KeyboardArrowDownIcon />
        }
      </IconButton>
    </MenuItem>
    <Collapse in={open} timeout="auto">
      <MenuItem sx={{ml: 2}} component={CustomLink(analysisAttendanceIds)} end to={`/analysis/attendance`}>
        <ListItemText>Attendance</ListItemText>
      </MenuItem>
      <MenuItem sx={{ml: 2}} component={CustomLink(analysisBalanceIds)} end to={`/analysis/balance`}>
        <ListItemText>Balance</ListItemText>
      </MenuItem>
      <MenuItem sx={{ml: 2}} component={CustomLink(analysisAnnualIds)} end to={`/analysis/annual`}>
        <ListItemText>Annual</ListItemText>
      </MenuItem>
    </Collapse>
  </>
}
