import { MenuList, MenuItem, Divider, ListItem, ListItemText, Collapse, IconButton } from '@mui/material';
import {
  NavLink
} from "react-router-dom";
import { CustomLink } from './Links';
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp';
import { includes, some } from 'lodash';
import { useMatches } from 'react-router-dom';
import { useEffect, useState } from 'react';

export const MenuChat = () => {

  const matches = useMatches();

  const menuIds = ["llm", "llm-id"];
  const subMenuIds = ['llm-history'];
  const allIds = [...menuIds, ...subMenuIds];
  const forceIds = [...subMenuIds];

  const active = some(matches, ({id}) => includes(allIds, id));
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
      component={CustomLink(menuIds)} end to={`/llm`}>
      <ListItemText>Chat</ListItemText>
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
        to={`/llm-history`}
        end
        >
        <ListItemText>History</ListItemText>
      </MenuItem>
    </Collapse>
  </>
}
