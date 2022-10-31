import { gql, useQuery } from '@apollo/client';
import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  FormControlLabel,
  Switch,
  FormControl,
  Box
} from '@mui/material';
import { get } from 'lodash';
import BookOnlineIcon from '@mui/icons-material/BookOnline';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams } from 'react-router-dom';
import { useEffect, useState } from 'react';


export const Members = () => {
  const [filterData, setFilterData] = useState({})

  let { data: members, loading, refetch } = useQuery(gql`query ($show_all: Boolean) {
    members (show_all: $show_all) {
      id,
      name,
      email,
      tokens
    }
  }`, {
    variables: {
      show_all: filterData.show_all
    }
  });
  members = get(members, "members", []) || []
  useEffect(() => {
    refetch()
  }, [filterData])

  return <div>
    <Box>
      <FormControl fullWidth sx={{m:2}}>
        <FormControlLabel
            control={
              <Switch 
                checked={get(filterData, 'show_all', false) || false}
                onChange={(event) => setFilterData({...filterData, show_all: event.target.checked})}/>
            }
            label="Show all" />
      </FormControl>
    </Box>
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Id</TableCell>
            <TableCell>Name</TableCell>
            <TableCell>Email</TableCell>
            <TableCell>Tokens</TableCell>
            <TableCell>Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {
            members.map((member) => (
              <TableRow key={member.id}>
                <TableCell>{member.id}</TableCell>
                <TableCell>{member.name}</TableCell>
                <TableCell>{member.email}</TableCell>
                <TableCell sx={{...(member.tokens < 0 ? {color: "red"} : {})}}>{member.tokens}</TableCell>
                <TableCell>
                  <IconButton component={Link} to={`/member/${member.id}/tokens`}>
                    <BookOnlineIcon />
                  </IconButton>
                  <IconButton component={Link} to={`/member/${member.id}`}>
                    <EditIcon />
                  </IconButton>

                </TableCell>
              </TableRow>
            ))
          }
        </TableBody>
      </Table>
    </TableContainer>
  </div>
}
