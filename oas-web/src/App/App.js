import './App.css';
import { gql, useQuery } from '@apollo/client';
import { Members } from '../Member/Members';
import { MenuList, MenuItem, ListItemText, Divider, ListItem, Drawer, IconButton, Box } from '@mui/material';
import { Outlet } from "react-router-dom";
import { styled, useTheme } from '@mui/material/styles';
import { useState } from 'react';
import { get } from 'lodash';
import { AppMenu } from './AppMenu';
import ChevronLeftIcon from '@mui/icons-material/ChevronLeft';
import ChevronRightIcon from '@mui/icons-material/ChevronRight';
import MenuIcon from '@mui/icons-material/Menu';

const DrawerHeader = styled('div')(({ theme }) => ({
  display: 'flex',
  alignItems: 'center',
  padding: theme.spacing(0, 1),
  // necessary for content to be below app bar
  ...theme.mixins.toolbar,
  justifyContent: 'flex-end',
}));

function App() {
  const [open, setOpen] = useState(true);
  const [title, setTitle] = useState('');

  const drawerWidth = 256;

  return (
    <div className="App">
      <Drawer
        sx={(theme) => ({
          [theme.breakpoints.up('md')]: {
            width: open ? drawerWidth : 0,
          },
          flexShrink: 0,
          '& .MuiDrawer-paper': {
            [theme.breakpoints.up('md')]: {
              width: open ? drawerWidth : 0,
            },
            boxSizing: 'border-box',
          },
        })}
        variant="persistent"
        anchor="left"
        open={open}
      >
        <DrawerHeader>
          <IconButton onClick={() => setOpen(false)}>
            <ChevronLeftIcon />
          </IconButton>
        </DrawerHeader>
        <AppMenu setOpen={setOpen} />
      </Drawer>
      <div className="content">
        <Box sx={{backgroundColor: '#1D7C81', display: 'flex'}}>
          <IconButton sx={{visibility: open ? 'hidden' : 'visible'}} onClick={() => setOpen(true)}>
            <MenuIcon />
          </IconButton>
          <Box sx={{pt: '11px'}}>{title}</Box>
        </Box>
        <Outlet context={{setTitle}} />
      </div>
    </div>
  );
}

export default App;
