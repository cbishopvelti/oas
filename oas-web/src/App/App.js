import './App.css';
import { gql, useMutation, useQuery, useSubscription } from '@apollo/client';
import { Members } from '../Member/Members';
import { MenuList, MenuItem, ListItemText, Divider, ListItem, Drawer, IconButton, Box, Alert } from '@mui/material';
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

const DrawerBar = ({ title, components }) => {
  const {loading, data} = useSubscription(gql`
    subscription {
      global_warnings {
        key,
        warning
      }
    }
  `)

  const [ mutate ] = useMutation(gql`
    mutation($key: String!) {
      global_warnings_clear(key: $key) {
        key,
        warning
      }
    }
  `)

  console.log("101 components", components);

  return <Box sx={{ minHeight: "48px", display: "flex", justifyContent: "space-between", width: "100%", mr: "16px"}}>
    <Box sx={{pt: '15px'}}>
      {title}
    </Box>

    {components.map((component, i) => {
      console.log("201", component)
      return <Box key={i} sx={{pt: '15px'}}>
        {component}
      </Box>
    })}

    {data?.global_warnings && <Box>
      {data.global_warnings.map((warning, i) => {
        return <Alert
          onClose={() => {
            mutate({
              variables: {
                key: warning.key
              }
            })
          }}
          severity="warning"
          key={i} sx={{ mt: "0px" }}>
          {warning.warning}
        </Alert>
      })}
    </Box>}
  </Box>
}

function App() {
  const [open, setOpen] = useState(true);
  const [title, setTitle] = useState('');
  const [components, setComponents] = useState([])

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
          <DrawerBar title={title} components={components} />
        </Box>
        <Outlet context={{setTitle, setComponents}} />

      </div>
    </div>
  );
}

export default App;
