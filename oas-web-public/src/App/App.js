// import logo from './logo.svg';
import './App.css';
import { Outlet, NavLink, useMatches } from 'react-router-dom'
import {
  Box, MenuList,
  MenuItem, ListItemText,
  IconButton, Drawer
} from '@mui/material'
import logo from "./acroyoga_logo.png"
import { useTheme, styled } from '@mui/material/styles';
import { useState, useEffect } from 'react';
import useMediaQuery from '@mui/material/useMediaQuery';
import MenuIcon from '@mui/icons-material/Menu';
import ChevronLeftIcon from '@mui/icons-material/ChevronLeft';


const DrawerHeader = styled('div')(({ theme }) => ({
  display: 'flex',
  alignItems: 'center',
  padding: theme.spacing(0, 1),
  // necessary for content to be below app bar
  ...theme.mixins.toolbar,
  justifyContent: 'flex-end',
}));

function App() {
  const [open, setOpen] = useState(false);
  const theme = useTheme();
  const matches = useMediaQuery(theme.breakpoints.down('md'));
  const routeMatchs = useMatches();

  useEffect(() => {
    if (matches) {
      setOpen(false)
    }
  }, [routeMatchs])

  const onClick = () => {
    if (matches) {
      setOpen(false)
    }
  }

  const drawerWidth = 244;

  return (
      <div className="App">
        <Drawer
          sx={(theme) => ({
            [theme.breakpoints.up('md')]: {
              width: open || !matches ? drawerWidth : 0,
            },
            flexShrink: 0,
            '& .MuiDrawer-paper': {
              [theme.breakpoints.up('md')]: {
                width: open || !matches ? drawerWidth : 0,
              },
              boxSizing: 'border-box',
            },
          })}
          anchor="left"
          variant="persistent"
          open={open || !matches}
          >
          {matches && <DrawerHeader sx={{
            backgroundColor: 'mediumpurple'
          }}>
            <IconButton onClick={() => setOpen(false)}>
              <ChevronLeftIcon />
            </IconButton>
          </DrawerHeader>}
          <div className="menu"
            style={{backgroundColor: 'mediumpurple'}}
            >
            <Box m={2}>
              <img width={212} src={logo} />
            </Box>
            <MenuList sx={{marginTop: 4}}>
              <MenuItem component={NavLink} end to={`/`}>
                <ListItemText>Home</ListItemText>
              </MenuItem>
              <MenuItem component={NavLink} to={'/register'}>
                <ListItemText>Register</ListItemText>
              </MenuItem>
              <MenuItem component={NavLink} to={'/tokens'}>
                <ListItemText>My Tokens</ListItemText>
              </MenuItem>
            </MenuList>
          </div>
        </Drawer>
        <Box className="content" p={2} sx={{position: "relative"}}>
          {matches && <IconButton sx={{visibility: open ? 'hidden' : 'visible'}} onClick={() => setOpen(true)}>
            <MenuIcon />
          </IconButton>}
          <Outlet />
        </Box>
      </div>
  );
}

export default App;
