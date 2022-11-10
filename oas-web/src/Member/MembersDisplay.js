import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
} from '@mui/material';
import { Link, useParams } from 'react-router-dom';
import BookOnlineIcon from '@mui/icons-material/BookOnline';
import EditIcon from '@mui/icons-material/Edit';
import CardMembershipIcon from '@mui/icons-material/CardMembership';
import CopyAllIcon from '@mui/icons-material/CopyAll';
import { join } from 'lodash'

export const MembersDisplay = ({members}) => {

  const copyAll = () => {
    navigator.clipboard.writeText(
      join(
        members.map(({email}) => email),
        ', '
      )
    )
  }

  return <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Id</TableCell>
            <TableCell>
              Name
            </TableCell>
            <TableCell>
              Email
              <IconButton onClick={copyAll}>
                <CopyAllIcon />
              </IconButton>  
            </TableCell>
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
                  <IconButton component={Link} to={`/member/${member.id}/membership-periods`}>
                    <CardMembershipIcon />
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
}