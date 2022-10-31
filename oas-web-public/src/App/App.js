// import logo from './logo.svg';
import './App.css';
import { Outlet, NavLink } from 'react-router-dom'
import { Box, MenuList, MenuItem, ListItemText } from '@mui/material'
import logo from "./acroyoga_logo.png"


function App() {
  return (
      <div className="App">
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
            <MenuItem component={NavLink} to={`/membership-info`}>
              <ListItemText>Member's Info</ListItemText>
            </MenuItem>
            <MenuItem component={NavLink} to={'/register'}>
              <ListItemText>Register</ListItemText>
            </MenuItem>
          </MenuList>
        </div>
        <Box className="content" p={2}>
          <Outlet />
        </Box>
      </div>
  );
}

export default App;
