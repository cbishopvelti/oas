import { gql, useQuery } from "@apollo/client";
import { useParams, useOutletContext } from "react-router-dom";

import { get } from 'lodash'
import { Credits } from "../Credits/Credits";
import { useEffect, useState } from "react";
import {
  Box,
  Button
} from '@mui/material';
import { TransferCredit } from "../Credits/TransferCredit";

export const MemberCredits = (params) => {

  const { setTitle } = useOutletContext();
  const [changeNo, setChangeNo] = useState(0);

  let { id } = useParams();
  if (id) {
    id = parseInt(id);
  }

  const { data, refetch } = useQuery(gql`
    query ($member_id: Int!) {
      member(member_id: $member_id) {
        id,
        name,
        credit_amount
      }
    }
  `, {
    variables: {
      member_id: parseInt(id)
    }
  })

  useEffect(() => {
      refetch()
  }, [changeNo])

  useEffect(() => {
    setTitle(`Member: ${get(data, 'member.name', id)}'s Credits: ${get(data, 'member.credit_amount', 0.0)}`);
  }, [data])

  return <div>
    <Box sx={{display: 'flex', gap: 2, m: 2, alignItems: 'center'}}>
      {/* <Button>Transfer credit</Button> */}
      <TransferCredit member_id={id} setChangeNo={setChangeNo} changeNo={ changeNo } />
    </Box>
    <Credits member_id={id} changeNo={changeNo} setChangeNo={setChangeNo} />
  </div>
}
