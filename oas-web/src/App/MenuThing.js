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


export const MenuThing = () => {

  const matches = useMatches();

  const thingIds = ["thing-id", "things"];
  const newThingIds = ['thing'];
  const allIds = [...thingIds, ...newThingIds];
  const forceIds = [...newThingIds];

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
      component={CustomLink(thingIds)} end to={`/things`}>
      <ListItemText>Things</ListItemText>
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
        to={`/thing`}
        end
        >
        <ListItemText>New Thing</ListItemText>
      </MenuItem>
    </Collapse>
  </>
}
