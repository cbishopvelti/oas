import { gql, useQuery } from "@apollo/client";
import { useParams } from "react-router-dom";
import {
  Table,
  TableContainer,
  TableHead,
  TableRow,
  TableCell,
  TableBody,
  IconButton
} from '@mui/material';
import { get } from 'lodash'
import moment from "moment";

const isUsable = (token) => {
  if (moment(token.expires_on).isBefore(moment())) {
    return false;
  }
  if(token.used_on) {
    return false
  }
  return true;
}

export const Tokens = (params) => {
  const { id } = useParams();

  const { data } = useQuery(gql`
    query ($member_id: Int!) {
      tokens(member_id: $member_id) {
        id,
        expires_on,
        used_on
      }
      member(member_id: $member_id) {
        id,
        name
      }
    }
  `, {
    variables: {
      member_id: parseInt(id)
    }
  })

  const tokens = get(data, 'tokens', []);

  return <div>
    <p>
      Tokens for <b>{get(data, 'member.name')}</b> (id: {id})
    </p>
    <TableContainer>
      <Table>
        <TableHead>
          <TableRow>
            <TableCell>Id</TableCell>
            <TableCell>Expires on</TableCell>
            <TableCell>Used on</TableCell>
          </TableRow>
        </TableHead>
        <TableBody>
          {
            tokens.map((token) => {
              const sx = {
                ...(!isUsable(token) ? {
                  color: "gray",
                  textDecoration: "line-through"
                }: {}),
                // color: "pink"
              }
              return (<TableRow key={token.id}>
                <TableCell sx={sx}>{token.id}</TableCell>
                <TableCell sx={sx}>{token.expires_on}</TableCell>
                <TableCell sx={sx}>{token.used_on}</TableCell>
              </TableRow>)
            })
          }
        </TableBody>
      </Table>
    </TableContainer>
  </div>
}