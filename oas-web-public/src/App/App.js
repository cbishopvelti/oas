// import logo from './logo.svg';
import './App.css';
import { Outlet, NavLink, useMatches, useOutletContext } from 'react-router-dom'
import {
  Box, MenuList,
  MenuItem, ListItem, ListItemText,
  IconButton, Drawer,
  Divider
} from '@mui/material'
import logo from "./acroyoga_logo.png"
import { useTheme, styled } from '@mui/material/styles';
import { useState, useEffect } from 'react';
import useMediaQuery from '@mui/material/useMediaQuery';
import MenuIcon from '@mui/icons-material/Menu';
import ChevronLeftIcon from '@mui/icons-material/ChevronLeft';
import { useQuery, gql } from '@apollo/client'
import { get } from 'lodash'
import { MenuChat } from './MenuChat';


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

  const { data, refetch, loading } = useQuery(gql`
  query {
    user {
      id,
      name,
      email,
      logout_link,
      is_admin,
      is_reviewer
    },
    public_config_config {
      enable_booking
    },
    public_config_llm {
      chat_enabled
    }
  }`)

  const enableBooking = get(data, 'public_config_config.enable_booking', false);

  const [outletContext, setOutletContext] = useState({
    refetchUser: refetch
  });
  useEffect(() => {
    refetch();
  }, [])
  useEffect(() => {
    setOutletContext({
      ...outletContext,
      user: get(data, 'user'),
      enableBooking: enableBooking,
      userLoading: loading
    })
  }, [data])

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
              {(!enableBooking || !get(data, 'user')) && <MenuItem component={NavLink} to={'/register'}>
                <ListItemText>Register</ListItemText>
              </MenuItem>}
              <MenuItem component={NavLink} to={'/credits'}>
                <ListItemText>My Credits</ListItemText>
              </MenuItem>
              <MenuItem component={NavLink} to={'/tokens'}>
                <ListItemText><s>My Tokens</s> (depricated)</ListItemText>
              </MenuItem>
              {enableBooking && get(data, 'user') && <MenuItem component={NavLink} to={'/bookings'}>
                <ListItemText>My Bookings</ListItemText>
              </MenuItem>}
            {enableBooking && !get(data, 'user') && <MenuItem onClick={onClick} sx={{padding: 0}}>
              <a style={{
                color: 'inherit',
                textDecoration: 'none',
                display: 'inline-block',
                width: '100%',
                padding: '6px 16px'
              }}
              href={`${process.env.REACT_APP_SERVER_URL}/members/log_in?callback_path=${encodeURIComponent("/bookings")}&callback_domain=public_url`}>My Bookings</a>
            </MenuItem>}

            { get(data, 'public_config_llm.chat_enabled', false) && <MenuChat />}

            {(get(data, 'user.is_admin') || get(data, 'user.is_reviewer')) && <MenuItem onClick={onClick} sx={{padding: 0}}>
              <a style={{
                color: 'inherit',
                textDecoration: 'none',
                display: 'inline-block',
                width: '100%',
                padding: '6px 16px'
              }}
              href={`${process.env.REACT_APP_ADMIN_URL}`}>Admin</a>
            </MenuItem>}

              {enableBooking && /* Fixed on the branch v2-credits-booking */ <MenuList>
                <Divider />

                {!!get(data, "user") && [<ListItem key="1">
                  <ListItemText>
                    {get(data, "user.name")}
                  </ListItemText>
                </ListItem>,
                <MenuItem onClick={onClick} key="2"
                  sx={{
                    padding: 0
                  }}
                >
                  <a
                    style={{
                      color: 'inherit', textDecoration: 'none',
                      display: 'inline-block',
                      width: '100%',
                      padding: '6px 16px'
                    }}
                    href={`${process.env.REACT_APP_SERVER_URL}${get(data, "user.logout_link")}`}
                    data-method="delete"
                    rel="nofollow"
                    >
                    Logout
                  </a>
                </MenuItem>]}
                {!get(data, "user") && <MenuItem onClick={onClick}
                  sx={{
                    padding: 0
                  }}
                >
                  <a
                    style={{
                      color: 'inherit',
                      textDecoration: 'none',
                      display: 'inline-block',
                      width: '100%',
                      padding: '6px 16px'
                    }}
                    href={`${process.env.REACT_APP_SERVER_URL}/members/log_in`}>
                    Login
                  </a>
                </MenuItem>}

              </MenuList>}
            </MenuList>
          </div>
        </Drawer>
        <Box className="content" p={2} sx={{position: "relative"}}>
          {matches && <IconButton sx={{visibility: open ? 'hidden' : 'visible'}} onClick={() => setOpen(true)}>
            <MenuIcon />
          </IconButton>}
          <Outlet context={[outletContext, setOutletContext]} />
        </Box>
      </div>
  );
}

export default App;
