import { gql, useQuery } from '@apollo/client';
import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton
} from '@mui/material';
import { get } from 'lodash';
import BookOnlineIcon from '@mui/icons-material/BookOnline';
import EditIcon from '@mui/icons-material/Edit';
import { Link, useParams } from 'react-router-dom';
import { useEffect } from 'react';


export const Members = () => {

  let { data: members, loading, refetch } = useQuery(gql`query {
    members {
      id,
      name,
      email,
      tokens
    }
  }`);
  members = get(members, "members", [])
  useEffect(() => {
    refetch()
  }, [])


  return <div>
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
