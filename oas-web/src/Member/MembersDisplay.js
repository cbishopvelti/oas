import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  TableSortLabel
} from '@mui/material';
import { Link, useParams } from 'react-router-dom';
import BookOnlineIcon from '@mui/icons-material/BookOnline';
import EditIcon from '@mui/icons-material/Edit';
import CardMembershipIcon from '@mui/icons-material/CardMembership';
import CopyAllIcon from '@mui/icons-material/CopyAll';
import { get, join, reverse, sortBy } from 'lodash'
import moment from 'moment'
// import { useState } from 'react';
import { useState } from '../utils/useState';
import FitnessCenterIcon from '@mui/icons-material/FitnessCenter';


export const MembersDisplay = ({
  data,
  dataKey,
  ExtraActions,
  showStatus
}) => {
  // const [orderBy, setOrderBy ] = useState();
  const [orderBy, setOrderBy] = useState(undefined, {id: 'MembersDisplay'});

  const sortByHandler = (column) => (b) => {
    if (orderBy?.column == column) {
      setOrderBy({
        ...orderBy,
        direction: orderBy.direction === "asc" ? "desc" : "asc"
      })
      return;
    }
    setOrderBy({
      column,
      direction: 'desc'
    })
  }
  if (orderBy) {
    data = sortBy(data, (dat) => {
      return (dataKey ? get(dat, dataKey) : dat)[orderBy.column];
    })
    if (orderBy.direction == 'asc') {
      data = reverse(data);
    }
  }

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
            <TableCell>
              <TableSortLabel
                active={orderBy?.column === 'id' || !orderBy}
                direction={orderBy?.direction}
                onClick={sortByHandler('id')}
              >Id</TableSortLabel>
            </TableCell>
            <TableCell>
              <TableSortLabel
                active={orderBy?.column === 'name'}
                direction={orderBy?.direction}
                onClick={sortByHandler('name')}
              >Name</TableSortLabel>
            </TableCell>
            <TableCell>
              <TableSortLabel
                active={orderBy?.column === 'email'}
                direction={orderBy?.direction}
                onClick={sortByHandler('email')}
              >Email</TableSortLabel>
              <IconButton title="Copy emails" onClick={copyAll}>
                <CopyAllIcon />
              </IconButton>

            </TableCell>
            {showStatus && <TableCell>
              Status
            </TableCell>}
            <TableCell>
              <TableSortLabel
                active={orderBy?.column === 'token_count'}
                direction={orderBy?.direction}
                onClick={sortByHandler('token_count')}
              >Tokens</TableSortLabel>
            </TableCell>
            <TableCell>
              <TableSortLabel
                active={orderBy?.column === 'credit_amount'}
                direction={orderBy?.direction}
                onClick={sortByHandler('credit_amount')}
              >
                Credits
              </TableSortLabel>
            </TableCell>
            <TableCell>Created at</TableCell>
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
                {showStatus && <TableCell>{member.member_status}</TableCell>}
                <TableCell sx={{...(member.token_count < 0 ? {color: "red"} : {})}}>{member.token_count}</TableCell>
                <TableCell sx={{...(member.credit_amount < 0 ? {color: "red"} : {})}}>{member.credit_amount}</TableCell>
                <TableCell>{moment(member.inserted_at).format("DD/MM/YYYY")}</TableCell>
                <TableCell>
                  <IconButton title={`Go to ${member.name}'s Tokens`} component={Link} to={`/member/${member.id}/tokens`}>
                    <BookOnlineIcon />
                  </IconButton>
                  <IconButton title={`Go to ${member.name}'s Attendance`} component={Link} to={`/member/${member.id}/attendance`}>
                    <FitnessCenterIcon />
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
