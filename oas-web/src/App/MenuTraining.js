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


export const MenuTraining = () => {
  
  const matches = useMatches();

  const trainingIds = ["training-id", "trainings", "member-attendance"];
  const newTrainingIds = ['training'];
  const allIds = [...trainingIds, ...newTrainingIds];
  const forceIds = [...newTrainingIds];

  const active = some(matches, ({id}) => includes(allIds, id));
  const forceActive = some(matches, ({id}) => includes(forceIds, id));
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
    <MenuItem
      component={CustomLink(trainingIds)} end to={`/trainings`}>
      <ListItemText>Trainings</ListItemText>
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
        to={`/training`}
        end
        >
        <ListItemText>New Training</ListItemText>
      </MenuItem>
    </Collapse>
  </>
}