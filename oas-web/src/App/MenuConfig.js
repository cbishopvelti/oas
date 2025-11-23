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

export const MenuConfig = () => {

  const matches = useMatches();

  const menuIds = ["config"];
  const subMenuIds = ['config-llm', 'config-content'];
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
      component={CustomLink(menuIds)} end to={`/config`}>
      <ListItemText>Config</ListItemText>
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
        to={`/config/content`}
        end
        >
        <ListItemText>Content</ListItemText>
      </MenuItem>
      <MenuItem
        sx={{ml:2}}
        component={NavLink}
        to={`/config/llm`}
        end
        >
        <ListItemText>Llm Context</ListItemText>
      </MenuItem>
    </Collapse>
  </>
}
