import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton,
  TableSortLabel, Dialog, DialogTitle,
  DialogContent
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
import QrCode2Icon from '@mui/icons-material/QrCode2';
import { useMutation, gql } from '@apollo/client'
import { useState as reactUseState } from 'react';
import QRCode from "react-qr-code";


export const MembersDisplay = ({
  data,
  dataKey,
  ExtraActions,
  showStatus
}) => {
  // const [orderBy, setOrderBy ] = useState();
  const [orderBy, setOrderBy] = useState(undefined, {id: 'MembersDisplay'});
  const [resetPasswordQrCode, setResetPasswordQrCode] = reactUseState(null);

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

  const [genQrCode] = useMutation(gql`
    mutation($member_id: Int!) {
      member_generate_reset_password_link(member_id: $member_id) {
        url
      }
    }
  `)
  const showLoginQrCode = (member_id, member_name) => async () => {
    console.log("show login qr code")
    const result = await genQrCode({
      variables: {
        member_id: member_id
      }
    });
    setResetPasswordQrCode({
      member_name: member_name,
      url: get(result, 'data.member_generate_reset_password_link.url')
    })
    console.log("008", result)
  }

  return <>
    <TableContainer>
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
                  <IconButton title={`Login user`} onClick={showLoginQrCode(member.id, member.name)}>
                    <QrCode2Icon />
                  </IconButton>
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

    {resetPasswordQrCode && <Dialog
      fullWidth={true}
      maxWidth={false}
      open={resetPasswordQrCode != null}
      onClose={() => setResetPasswordQrCode(null)}
      aria-labelledby="alert-dialog-title"
      aria-describedby="alert-dialog-description"
    >
      <DialogTitle id="alert-dialog-title">
        {`Reset ${resetPasswordQrCode.member_name}'s password`}
      </DialogTitle>
      <DialogContent
        style={{
            display: 'flex',
            justifyContent: 'center',
            alignItems: 'center',
            overflow: 'hidden' // Prevents scrollbars if calculation is slightly off
          }}
      >
        <QRCode
          size={256}
          style={{
            flexGrow: "9999",
            // 1. Let the QR code be as tall as the screen minus header/padding (approx 150px)
            maxHeight: "calc(100vh - 150px)",
            // 2. Let it be as wide as the dialog (for mobile)
            maxWidth: "100%",
            // 3. IMPORTANT: Set width/height to auto so the aspect ratio determines the actual size
            height: "auto",
            width: "auto"
          }}
          value={ resetPasswordQrCode.url  }
          viewBox={`0 0 256 256`}
          />
      </DialogContent>
    </Dialog>}
  </>
}
