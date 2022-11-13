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
import { get, join } from 'lodash'

export const MembersDisplay = ({data, dataKey, ExtraActions}) => {

  const copyAll = () => {
    navigator.clipboard.writeText(
      join(
        data.map((dat) =>
          (dataKey ? get(dat, dataKey) : dat).email
        ),
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
              <IconButton title="Copy emails" onClick={copyAll}>
                <CopyAllIcon />
              </IconButton>  
            </TableCell>
            <TableCell>Tokens</TableCell>
            <TableCell>Actions</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {
            data.map((dat) => {
              const member = (dataKey ? get(dat, dataKey) : dat);
              return (<TableRow key={member.id}>
                <TableCell>{member.id}</TableCell>
                <TableCell>{member.name}</TableCell>
                <TableCell>{member.email}</TableCell>
                <TableCell sx={{...(member.token_count < 0 ? {color: "red"} : {})}}>{member.token_count}</TableCell>
                <TableCell>
                  <IconButton title={`Go to ${member.name}'s Tokens`} component={Link} to={`/member/${member.id}/tokens`}>
                    <BookOnlineIcon />
                  </IconButton>
                  <IconButton component={Link} title={`Go to ${member.name}'s Membership periods`} to={`/member/${member.id}/membership-periods`}>
                    <CardMembershipIcon />
                  </IconButton>
                  <IconButton component={Link} title={`Edit ${member.name}`} to={`/member/${member.id}`}>
                    <EditIcon />
                  </IconButton>

                  {ExtraActions && <ExtraActions data={dat} member_id={member.id} member={member} />}
                </TableCell>
              </TableRow>
            )})
          }
        </TableBody>
      </Table>
    </TableContainer>
}