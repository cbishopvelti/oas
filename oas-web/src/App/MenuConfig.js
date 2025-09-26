import { MenuList, MenuItem, Divider, ListItem, ListItemText, Collapse, IconButton } from '@mui/material';
import { NavLink, useMatches } from "react-router-dom";
import { includes, some } from 'lodash';
import { useState } from "react";
import KeyboardArrowDownIcon from '@mui/icons-material/KeyboardArrowDown';
import KeyboardArrowUpIcon from '@mui/icons-material/KeyboardArrowUp';

export const MenuConfig = ({
  setMenuOpen
}) => {

  const matches = useMatches();
  console.log("001 matches", matches);


  const rootIds = ["config"];
  const subIds = ["config-plaid"]
  const allIds = [...rootIds, ...subIds];

  const active = some(matches, ({id}) => includes(allIds, id));
  const forceActive = some(matches, ({id}) => includes(subIds, id));

  const [open, setOpen] = useState(active);

  const handleOpen = (event) => {
    event.stopPropagation();
    event.preventDefault();

    if (forceActive) {
      return;
    }

    setOpen(!open)

    return false;
  }

  useMutation(gql`
    mutation ($client_id: String) {
      success
    }
  `)

  return <>
    <MenuItem component={NavLink} end to="/config">
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
        to={`/config/plaid`}
        end
        >
        <ListItemText>Plaid</ListItemText>
      </MenuItem>
    </Collapse>
  </>
}
