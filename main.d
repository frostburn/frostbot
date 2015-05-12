import std.stdio;
import std.string;
import std.format;
import std.math;
import std.algorithm;
import std.random;
import std.parallelism;
import core.thread;

import utils;
import board8;
import board11;
import bit_matrix;
import state;
import polyomino;
import defense_state;
//import game_state;
//import search_state;
import defense_search_state;
import defense;
import eyeshape;
static import monte_carlo;
import heuristic;
import fast_math;
import ann;
import likelyhood;
import wdl_node;
import direct_mc;
import pattern3;


// Lol "makefile"
// dmd main.d utils.d board8.d board11.d bit_matrix.d state.d polyomino.d defense_state.d defense_search_state.d defense.d eyeshape.d monte_carlo.d heuristic.d fast_math.d ann.d likelyhood.d wdl_node.d direct_mc.d pattern3.d
// -O -release -inline -noboundscheck

/*
void print_state(SearchState!Board8 ss, int depth){
    //
    //writeln(ss.player_unconditional);
    //writeln(ss.opponent_unconditional);
    //Board8 b;
    //foreach (move; ss.moves){
    //    b |= move;
    //}
    //writeln(b);
    if (depth <= 0){
        return;
    }
    if (ss.is_leaf && ss.lower_bound != ss.upper_bound){
        writeln(ss.state);
        writeln(ss.lower_bound, ", ", ss.upper_bound);
        writeln("Num children:", ss.children.length);
        foreach (child; ss.children){
            writeln(" Child: ", child.lower_bound, ", ", child.upper_bound);
        }
        Thread.sleep(dur!("msecs")(1000));
        writeln;
    }
    foreach (child; ss.children){
        //if ((ss.state.black_to_play && child.lower_bound == ss.lower_bound) || (!ss.state.black_to_play && child.upper_bound == ss.upper_bound))
            print_state(cast(SearchState!Board8)child, depth - 1);
    }
}
*/

/*
void print_path(SearchState8 ss, int depth){
    if (depth <= 0){
        return;
    }
    writeln(ss);
    writeln(ss.player_useless | ss.opponent_useless);
    foreach (child; ss.children){
        writeln(" ", child.lower_bound, ", ", child.upper_bound, ", max=", child.state.black_to_play);
    }
    bool found_one = false;
    foreach (child; ss.children){
        if (-child.lower_bound == ss.upper_bound && -child.upper_bound == ss.lower_bound){
            print_path(cast(SearchState8)child, depth - 1);
            found_one = true;
            break;
        }
    }
    if (!found_one){
        foreach (child; ss.children){
            if (-child.upper_bound == ss.lower_bound){
                print_path(cast(SearchState8)child, depth - 1);
                break;
            }
        }
    }
}
*/

double compete(int[Pattern3] pw1, int[Pattern3] pw2)
{
    auto stats12 = Statistics(-8 * 7, 8 * 7);
    auto stats21 = Statistics(-8 * 7, 8 * 7);
    foreach (j; 0..1000){
        auto s = State8(rectangle8(8, 7));
        foreach (i; 0..35){
            assert(s.black_to_play);
            s = monte_carlo.child_by_pattern3(s, pw1);
            s = monte_carlo.child_by_pattern3(s, pw2);
        }
        auto e = Board8();
        stats12.add_value(controlled_liberty_score(s, e, e, e, e, e, e));
        s = State8(rectangle8(8, 7));
        foreach (i; 0..35){
            assert(s.black_to_play);
            s = monte_carlo.child_by_pattern3(s, pw2);
            s = monte_carlo.child_by_pattern3(s, pw1);
        }
        stats21.add_value(controlled_liberty_score(s, e, e, e, e, e, e));
    }
    //writeln(stats12);
    //writeln(stats21);
    return stats12.mean - stats21.mean;
}


void expand_to(WDLNode8 root, int depth)
{
    if (depth <= 0){
        return;
    }
    root.make_children;
    foreach (child; root.children){
        expand_to(child, depth - 1);
    }
}


void main()
{
    writeln("main");

    Transposition[DefenseState8] empty;
    auto defense_transposition_table = &empty;

    Transposition[CanonicalState8] empty2;
    auto transposition_table = &empty2;

    //WDLNode8[CanonicalState8] empty3;
    //auto node_pool = &empty3;

    DirectMCNode8[CanonicalState8] empty3;
    auto node_pool = &empty3;

    /*
    auto s = State8(rectangle8(4, 4));

    auto ss = new SearchState8(s, transposition_table, defense_transposition_table);
    ss.iterative_deepening(1, 36);
    writeln(ss);
    */

    /*
    auto ss = State8(rectangle8(4, 3));
    ss.player = Board8(0, 0) | Board8(2, 0);
    ss.opponent = Board8(1, 0) | Board8(1, 1) | Board8(2, 1) | Board8(2, 2);
    auto cs = CanonicalState8(ss);
    writeln(cs);
    auto result = analyze_state!(Board8, CanonicalState8)(cs, Board8(), Board8(), defense_transposition_table);
    writeln(result);
    assert(1 ==2);
    */

    int width = 8;
    int height = 7;
    auto s = State8(rectangle8(width, height));
    s.value_shift = 0;
    //s.player = rectangle8(1, 4).east(2);
    //s.opponent = rectangle8(2, 4) & ~rectangle8(1, 3) | Board8(3, 1);
    //s.make_move(Board8(1, 1));
    //s.make_move(Board8(2, 1));
    /*
    s.make_move(Board8(1, 1));
    s.make_move(Board8(2, 2));
    s.make_move(Board8(2, 1));
    s.make_move(Board8(1, 2));
    s.make_move(Board8(0, 2));
    s.make_move(Board8(3, 1));
    s.make_move(Board8(1, 3));
    */

    /*
    auto p = Pattern3(1, 0);
    p.canonize;
    int[Pattern3] pattern_weights;
    pattern_weights[p] = 6400;
    foreach (i; 0..20){
        s = monte_carlo.child_by_pattern3(s, pattern_weights);
        writeln(s);
    }
    */

    //int[hash_t] _winner = [1831:56, 0:61, 4097:22, 50983:0, 48943:7, 1:18, 44863:45, 10557:16, 16386:30, 18191:11, 11069:33, 36647:17, 2560:4, 34575:50, 42759:26, 26375:0, 2:45, 14095:27, 44847:34, 3847:53, 38695:56, 1911:56, 1807:39, 34607:36, 12:56, 512:55, 43323:3, 10:44, 5903:10, 513:54, 12207:1, 22287:9, 32769:56, 42767:50, 34687:3, 12089:37, 1799:50, 7975:32, 4007:12, 10015:10, 1839:4, 1847:27, 11065:56, 12223:13, 11577:7, 16303:8, 9991:11, 3959:14, 16175:33, 12159:3, 12095:22, 7943:43, 12039:8, 1025:16, 10553:6, 2050:40, 768:59, 34599:7, 1919:51, 5927:19, 12287:0, 9999:39, 3895:15, 22311:12, 10555:6, 26383:8, 3879:7, 5:28, 256:34, 18183:31, 28607:55, 10079:52, 26939:13, 8194:40, 30471:48, 12079:63, 18215:44, 20231:35, 3072:51, 28479:16, 3:31, 1280:58, 258:46, 14087:41];
    //int[hash_t] _winner = [0:49, 5121:41, 37158:63, 30978:4, 8199:20, 28479:4, 7171:6, 18993:39, 2560:55, 15618:49, 5935:52, 14594:17, 1075:45, 42521:6, 18482:27, 8103:51, 29952:24, 56833:16, 55335:44, 53514:20, 55:38, 4366:50, 9496:13, 4143:52, 53550:56, 36874:57, 13322:60, 43325:45, 1847:59, 6657:6, 53294:24, 28473:4, 49717:21, 40986:27, 37130:58, 55055:57, 629:33, 35889:58, 32002:30, 46091:15, 34819:13, 47407:63, 53260:54, 11267:25, 38949:51, 40973:35, 57370:2, 43011:6, 32859:55, 54785:34, 24858:3, 22531:37, 34855:39, 41565:23, 14337:28, 33060:44, 6656:63, 13:24, 58371:21, 51007:50, 21515:0, 18437:53, 16956:53, 27581:28, 780:60, 17969:23, 41053:48, 28679:25, 32519:52, 1025:58, 12159:29, 29699:22, 165:30, 29962:10, 24590:43, 22287:39, 13056:7, 22311:52, 37132:39, 38703:41, 11:54, 18439:0, 50227:46, 45326:11, 20481:46, 59394:40, 34599:28, 50201:6, 16908:25, 28685:1, 46081:41, 33317:19, 48943:36, 30479:42, 18486:14, 18183:1, 47362:19, 61453:56, 16409:0, 525:14, 16654:29, 17459:49, 7169:43, 61710:63, 5633:19, 33062:40, 14848:56, 12300:9, 24359:25, 41477:62, 677:15, 21505:5, 2613:25, 51765:29, 61443:57, 40449:61, 64770:62, 9991:63, 1082:57, 42009:22, 62730:24, 50713:46, 256:48, 6181:31, 28607:12, 8729:19, 48903:32, 524:43, 57881:57, 27963:30, 58626:25, 53259:59, 16135:55, 25368:23, 294:36, 18239:22, 572:23, 11522:57, 1839:37, 6311:52, 5386:58, 5903:59, 8728:10, 20495:23, 13314:15, 38401:52, 16700:22, 1823:7, 16642:38, 26383:45, 16666:47, 16303:55, 12207:50, 9241:39, 17457:19, 53262:14, 19506:48, 57347:60, 49205:15, 9243:50, 4609:36, 512:43, 43323:21, 31:2, 4388:0, 565:53, 49213:13, 44800:60, 25858:22, 2215:56, 6180:57, 7:20, 9240:0, 3122:39, 33333:13, 20750:18, 18485:6, 16652:36, 1537:0, 3895:11, 5123:38, 54282:41, 49177:55, 57612:12, 32807:30, 28675:27, 17433:43, 49:22, 44857:1, 45071:7, 21005:54, 1290:18, 36353:4, 55087:10, 58395:26, 54:28, 37:36, 16415:18, 20491:55, 20518:11, 46:22, 32771:43, 45059:39, 33795:4, 2677:53, 33341:10, 53295:9, 191:44, 6948:9, 34575:39, 24605:61, 9482:62, 573:1, 57375:0, 41484:27, 43837:40, 18949:53, 17435:11, 33397:42, 13578:55, 37389:30, 32795:63, 28677:15, 53251:35, 2051:30, 29697:35, 33596:40, 90:18, 51494:47, 11579:14, 46346:11, 13315:4, 50:16, 9472:45, 2087:26, 48129:29, 62474:5, 28942:29, 12289:61, 18997:53, 58393:39, 6436:50, 35445:46, 44807:44, 26941:0, 1304:14, 9752:43, 3959:24, 1081:14, 18470:2, 24487:22, 33803:22, 14592:15, 53286:49, 12:43, 10757:47, 36879:13, 18487:21, 10242:24, 42752:44, 12287:5, 1816:62, 27141:31, 33793:55, 17467:56, 53773:55, 4390:30, 16128:20, 12301:53, 14767:0, 26629:58, 45324:40, 1306:38, 541:19, 21284:36, 22533:3, 26136:52, 18207:23, 16435:19, 41055:60, 8462:50, 41994:60, 32821:42, 33841:62, 50959:61, 35891:42, 167:6, 39206:51, 1911:5, 32829:63, 39939:53, 13570:31, 65025:51, 40987:19, 8716:35, 16921:15, 24327:31, 1887:15, 62977:58, 1:50, 32826:57, 45068:25, 26939:50, 32814:49, 32895:13, 9218:35, 19762:58, 18215:32, 60674:34, 29196:13, 6692:0, 33150:45, 48386:26, 49179:53, 46083:23, 1855:19, 2306:57, 41218:3, 56100:35, 35110:2, 57356:50, 20526:60, 18483:3, 32256:15, 3879:59, 38:24, 62:46, 21507:33, 37898:41, 53518:45, 8287:44, 18471:18, 4097:58, 59395:1, 59143:49, 49155:9, 10687:29, 3847:8, 48641:34, 1282:11, 50490:4, 26399:10, 51:49, 29707:28, 16925:38, 59397:9, 316:28, 57:0, 49470:15, 4876:46, 4133:43, 34607:17, 1593:12, 54275:54, 16175:53, 8450:20, 36727:24, 23553:0, 19507:26, 6912:46, 24591:16, 54273:16, 6146:40, 3074:63, 42759:28, 32257:62, 43327:6, 37134:53, 32512:48, 1831:23, 17465:42, 27650:42, 20782:53, 10498:57, 7424:41, 9219:47, 33070:63, 38915:3, 22695:37, 11069:59, 36875:33, 24583:59, 20527:21, 1799:6, 382:59, 34329:47, 49980:16, 16698:0, 30727:61, 18738:52, 34869:29, 8195:23, 12299:10, 8472:37, 6147:58, 60221:6, 44290:30, 2852:40, 20772:56, 38695:56, 41501:7, 12089:30, 189:58, 7975:8, 34058:10, 25627:10, 18367:48, 12293:56, 33548:43, 18231:17, 24588:46, 62465:47, 43010:55, 43013:12, 24578:18, 8285:55, 53258:11, 19459:61, 51506:46, 25603:38, 16690:13, 1561:9, 8221:41, 63493:30, 18726:33, 21514:63, 30464:31, 51510:0, 16678:53, 44347:8, 5927:17, 32819:52, 42240:60, 12039:47, 35841:18, 63247:26, 18435:6, 16909:41, 41228:33, 26375:13, 32687:56, 44863:44, 48384:29, 38154:45, 5130:37, 11776:58, 37166:40, 24602:9, 64005:41, 19505:50, 10243:2, 57357:13, 16694:13, 53261:14, 12095:26, 13825:44, 57346:28, 27449:6, 44034:37, 4110:32, 9753:39, 39:46, 23077:45, 16957:8, 28687:28, 8972:62, 2050:1, 53263:8, 24603:16, 49165:14, 50737:27, 15363:52, 302:6, 33074:52, 49932:28, 3585:33, 14339:63, 16443:58, 2099:23, 16423:20, 53516:8, 1027:49, 51239:21, 17176:62, 32831:16, 61247:46, 12290:5, 39937:39, 8460:26, 18200:9, 8197:51, 55299:13, 61:50, 54538:40, 23808:31, 22319:61, 58124:43, 8733:29, 46090:25, 27453:22, 1807:1, 3378:49, 18690:5, 23041:43, 2047:4, 24065:51, 25356:46, 24579:35, 25093:10, 9307:15, 40962:7, 11266:48, 16437:28, 4271:37, 23040:25, 16920:28, 39716:59, 49190:23, 36902:44, 34687:24, 25602:34, 10079:0, 14095:51, 22786:5, 51253:24, 36877:49, 12801:1, 61452:59, 57602:1, 8217:42, 8194:16, 266:47, 39204:21, 9999:46, 45067:56, 42767:6, 10557:40, 11777:39, 32815:9, 49167:0, 9227:59, 6661:45, 16391:40, 4111:28, 45836:55, 30723:54, 29:31, 27071:55, 49676:50, 38951:59, 16945:30, 45070:35, 2358:49, 47617:48, 6438:49, 36401:2, 1585:39, 50235:50, 22566:55, 38913:15, 24607:36, 12295:61, 57869:32, 2354:18, 41740:62, 1330:36, 65327:46, 33849:62, 47106:55, 18599:18, 22535:34, 4099:36, 12291:16, 28684:4, 36146:31, 42776:38, 34615:9, 8204:33, 28674:22, 19458:40, 57351:39, 37668:16, 38950:63, 35329:26, 10555:29, 16399:52, 43015:50, 1034:54, 1051:27, 56323:6, 318:59, 30209:6, 3073:47, 24:38, 54028:37, 22530:44, 10245:2, 58650:39, 45066:0, 12556:47, 2561:0, 2565:52, 50983:30, 58:51, 2167:34, 16953:52, 51203:53, 24834:25, 91:23, 55809:39, 17714:8, 18742:5, 13824:51, 14639:63, 53249:21, 16447:10, 21260:2, 17411:40, 20279:0, 34305:50, 10:48, 2816:4, 26626:11, 11197:4, 310:15, 33034:63, 45580:14, 4108:10, 1074:40, 6182:51, 6309:51, 2086:20, 17085:16, 12032:42, 47621:15, 59707:36, 32781:20, 36876:58, 36911:62, 53761:8, 9728:1, 16398:47, 31237:22, 53542:57, 8223:37, 2053:0, 59709:43, 36865:46, 32783:6, 16901:22, 6144:4, 29197:30, 40972:39, 41497:57, 33817:10, 22567:24, 2:56, 44847:41, 49677:18, 282:23, 17212:8, 26943:57, 45322:13, 4134:59, 16387:27, 6183:40, 4644:45, 15616:25, 40989:18, 32887:15, 49466:33, 10015:46, 12812:43, 828:28, 16397:53, 45581:26, 57369:60, 33292:6, 255:11, 2102:11, 1338:36, 41987:11, 2609:50, 62220:16, 53:44, 12544:9, 28940:35, 2103:16, 17164:50, 37413:16, 32769:12, 1280:63, 33038:22, 23076:24, 1083:22, 1959:9, 20231:22, 62467:29, 6063:19, 1115:29, 23332:0, 8207:60, 17977:12, 26631:59, 4135:29, 36867:57, 33802:60, 27:14, 53031:38, 30471:41, 49215:17, 42266:55, 19714:4, 33086:57, 50999:45, 20746:22, 280:1, 52275:37, 1983:26, 6693:37, 9242:20, 63746:63, 59167:32, 2101:60, 52227:59, 61708:15, 34871:51, 268:35, 41995:44, 53047:30, 1049:32, 21770:51, 53797:35, 15360:14, 605:6, 57868:36, 3123:14, 50234:24, 63490:54, 63495:52, 16445:59, 20748:51, 57349:59, 49211:63, 25117:49, 8218:3, 16442:3, 15361:35, 54283:61, 55845:50, 25882:60, 13568:24, 16446:33, 49422:38, 20490:39, 306:1, 15104:24, 59160:35, 27906:21, 33036:13, 49164:34, 42264:20, 10553:59, 40991:22, 6149:50, 43525:3, 14:26, 12223:3, 9216:51, 57861:33, 8984:53, 32780:36, 61965:17, 6402:42, 270:54, 51251:5, 42783:4, 16411:53, 44035:29, 57359:13, 49689:9, 44927:57, 7426:55, 4900:12, 804:3, 8205:47, 8219:49, 4364:57, 24601:26, 24320:35, 1967:40, 60418:31, 126:18, 8709:54, 49166:7, 3072:51, 2055:28, 32830:44, 36903:40, 44345:7, 59:35, 10247:52, 51255:63, 33572:18, 60419:38, 30722:34, 61454:59, 16413:2, 12554:14, 34867:11, 23205:13, 23296:33, 21029:32, 40743:29, 33819:20, 40985:0, 2098:18, 16386:18, 16439:54, 4142:52, 22822:41, 20517:53, 8474:31, 32779:13, 29698:61, 26627:22, 28930:58, 6400:39, 20483:26, 59399:38, 41230:59, 26137:59, 35126:13, 569:27, 20655:54, 27651:2, 119:15, 40974:11, 2597:19, 18191:35, 9306:15, 11577:62, 65287:31, 57127:23, 33078:0, 16410:10, 701:54, 5131:35, 42497:5, 32806:32, 9474:16, 1792:37, 34098:6, 35365:48, 1919:5, 49446:25, 517:41, 65280:27, 32823:58, 9498:42, 62475:49, 14341:52, 33082:35, 537:59, 11065:8, 31746:11, 57885:43, 14343:18, 2342:17, 10559:20, 40967:31, 4645:26, 42011:16, 59151:24, 46593:30, 12079:45, 32778:17, 40963:55, 57371:58, 15873:16, 25625:60, 49214:3, 32559:20, 36910:49, 55590:33, 36:3, 53772:50, 61191:12, 127:0, 39425:2, 20391:31, 548:23, 4107:62, 36647:36, 35381:41, 49191:54, 25100:24, 32885:53, 24844:1, 7943:40, 35122:22, 57358:62, 48896:40, 16551:30, 9226:34, 31747:3, 50745:19, 59711:28, 12303:29, 23810:50, 16422:6, 15362:36, 13313:16, 34854:39, 34679:60, 13323:48, 5:53, 29954:2, 32805:52, 10685:56, 17688:32, 37644:14, 561:5, 29452:30, 51238:9, 12558:31, 37889:51, 47109:31, 38671:37, 3584:10, 13068:1, 9217:46, 17466:48, 16702:51, 33281:50, 9562:55, 24846:38, 12805:27, 25101:57, 45069:7, 8717:50, 792:34, 25113:15, 60731:56, 37899:40, 1370:53, 26392:26, 47107:8, 32827:25, 42242:33, 20263:6, 17945:34, 29706:42, 16575:46, 63:20, 536:26, 18434:16, 22017:43, 57614:48, 93:28, 3633:27, 49203:7, 61964:60, 34106:10, 28686:6, 30725:27, 35843:5, 20494:61, 18343:40, 4362:53, 42250:60, 53285:36, 47105:9, 15:38, 37388:25, 35620:52, 292:13, 45057:22, 33843:20, 28423:51, 12800:44, 9729:12, 34935:32, 7681:59, 49420:2, 29189:17, 4109:48, 34623:41, 4007:60, 34353:9, 17690:38, 49210:18, 44545:41, 4106:9, 33305:9, 22447:46, 47111:16, 55079:40, 24581:31, 95:14, 549:38, 39461:28, 47:3, 20774:33, 8797:46, 33851:51, 12546:16, 175:17, 21004:53, 59909:52, 57626:24, 10008:45, 3075:57, 42330:39, 25:41, 45569:15, 52785:36, 15872:9, 33850:24, 36878:15, 2725:58, 25880:61, 1073:38, 36901:12, 7936:32, 20017:26, 57373:9, 56321:26, 25626:15, 3:61, 41242:8, 14849:43, 14853:40, 768:5, 50179:62, 63491:45, 117:54, 40975:62, 23555:35, 346:36, 34361:37, 12298:26, 6145:9, 14087:63, 46863:39, 314:22, 60:40, 40965:58, 16949:11, 12302:54, 9984:56, 20492:63, 16396:0, 43266:19, 36663:23, 8206:42, 14080:28, 24589:55, 58905:37, 26:15, 49725:50, 23045:20, 61241:16, 17722:57, 27961:48, 32782:45, 4620:60, 59650:27, 17666:8, 3328:2, 42075:40, 55334:0, 49207:62, 12813:19, 3840:32, 42847:34, 53287:48, 3121:63, 6151:59, 52530:35, 41985:46, 48131:14, 4621:48, 61455:18, 33883:32, 2097:31, 14338:33, 513:39, 3330:36, 258:14, 2596:37, 64515:22, 16389:51, 20993:40, 4398:39, 1035:40, 26882:59, 33293:50, 20519:45, 32793:60, 41485:23, 33084:6, 37891:12, 6821:6, 50203:29, 37377:35, 20493:54];
    int[hash_t] _winner = [0:37, 5121:16, 37158:22, 30978:13, 8199:0, 28479:7, 7171:57, 18993:55, 2560:59, 15618:47, 5935:12, 14594:31, 1075:38, 42521:43, 18482:3, 8103:54, 29952:50, 56833:0, 55335:42, 53514:36, 55:15, 4366:36, 9496:41, 4143:42, 53550:50, 36874:50, 13322:48, 43325:25, 1847:19, 6657:24, 53294:24, 28473:23, 49717:6, 40986:50, 37130:58, 55055:19, 629:41, 35889:15, 32002:36, 46091:18, 34819:43, 47407:32, 53260:7, 11267:41, 38949:56, 40973:54, 57370:53, 43011:60, 32859:55, 54785:48, 24858:45, 22531:32, 34855:29, 41565:7, 14337:45, 33060:36, 6656:43, 13:46, 58371:36, 51007:14, 21515:26, 18437:58, 16956:16, 27581:30, 780:26, 17969:0, 41053:27, 28679:5, 32519:53, 1025:14, 12159:59, 29699:43, 165:40, 29962:43, 24590:18, 22287:33, 13056:0, 22311:58, 37132:37, 38703:11, 11:39, 18439:40, 50227:23, 45326:42, 20481:53, 59394:15, 34599:40, 50201:50, 16908:45, 28685:31, 46081:40, 33317:1, 48943:5, 30479:60, 18486:35, 18183:6, 47362:42, 61453:28, 16409:26, 525:49, 16654:5, 17459:52, 7169:35, 61710:22, 5633:1, 33062:35, 14848:7, 12300:62, 24359:39, 41477:7, 677:3, 21505:32, 2613:38, 51765:44, 61443:55, 40449:50, 64770:37, 9991:21, 1082:44, 42009:24, 62730:34, 50713:47, 256:1, 6181:2, 28607:39, 8729:53, 48903:31, 524:11, 57881:42, 27963:15, 58626:37, 53259:34, 16135:46, 25368:56, 294:24, 18239:50, 572:59, 11522:42, 1839:13, 6311:6, 5386:47, 5903:14, 8728:48, 20495:42, 13314:60, 38401:18, 16700:11, 1823:44, 16642:19, 26383:23, 16666:11, 16303:48, 12207:6, 9241:56, 17457:51, 53262:19, 19506:13, 57347:53, 49205:62, 9243:60, 4609:48, 512:35, 43323:39, 31:50, 4388:58, 565:63, 49213:60, 44800:63, 25858:2, 2215:51, 6180:9, 7:20, 9240:10, 3122:2, 33333:24, 20750:63, 18485:33, 16652:53, 1537:40, 3895:59, 5123:24, 54282:5, 49177:2, 57612:10, 32807:51, 28675:1, 17433:54, 49:40, 44857:48, 45071:22, 21005:37, 1290:22, 36353:7, 55087:50, 58395:41, 54:17, 37:36, 16415:14, 20491:14, 20518:55, 46:39, 32771:33, 45059:30, 33795:4, 2677:10, 33341:1, 53295:36, 191:3, 6948:58, 34575:47, 24605:39, 9482:34, 573:37, 57375:50, 41484:62, 43837:38, 18949:52, 17435:27, 33397:2, 13578:26, 37389:24, 32795:20, 28677:7, 53251:32, 2051:56, 29697:5, 33596:50, 90:26, 51494:45, 11579:0, 46346:50, 13315:48, 50:24, 9472:19, 2087:11, 48129:62, 62474:53, 28942:44, 12289:31, 18997:5, 58393:27, 6436:58, 35445:14, 44807:49, 26941:57, 1304:28, 9752:28, 3959:49, 1081:5, 18470:52, 24487:47, 33803:30, 14592:18, 53286:9, 12:44, 10757:58, 36879:1, 18487:13, 10242:42, 42752:40, 12287:3, 1816:16, 27141:21, 33793:14, 17467:60, 53773:42, 4390:56, 16128:8, 12301:48, 14767:54, 26629:30, 45324:21, 1306:4, 541:57, 21284:8, 22533:55, 26136:33, 18207:56, 16435:24, 41055:51, 8462:47, 41994:31, 32821:28, 33841:40, 50959:57, 35891:30, 167:28, 39206:7, 1911:1, 32829:31, 39939:35, 13570:17, 65025:59, 40987:40, 8716:20, 16921:33, 24327:16, 1887:27, 62977:53, 1:47, 32826:34, 45068:46, 26939:1, 32814:3, 32895:32, 9218:14, 19762:26, 18215:12, 60674:14, 29196:39, 6692:35, 33150:13, 48386:6, 49179:24, 46083:26, 1855:28, 2306:42, 41218:22, 56100:45, 35110:56, 57356:9, 20526:9, 18483:24, 32256:58, 3879:62, 38:5, 62:58, 21507:2, 37898:46, 53518:12, 8287:23, 18471:14, 4097:30, 59395:43, 59143:2, 49155:48, 10687:11, 3847:15, 48641:19, 1282:3, 50490:35, 26399:53, 51:61, 29707:54, 16925:7, 59397:39, 316:40, 57:62, 49470:1, 4876:52, 4133:44, 34607:24, 1593:4, 54275:27, 16175:25, 8450:8, 36727:6, 23553:59, 19507:8, 6912:34, 24591:20, 54273:52, 6146:41, 3074:53, 42759:24, 32257:61, 43327:21, 37134:29, 32512:60, 1831:4, 17465:3, 27650:24, 20782:46, 10498:47, 7424:15, 9219:62, 33070:28, 38915:2, 22695:23, 11069:1, 36875:1, 24583:19, 20527:36, 1799:5, 382:57, 34329:24, 49980:63, 16698:29, 30727:53, 18738:8, 34869:30, 8195:4, 12299:6, 8472:58, 6147:38, 60221:57, 44290:13, 2852:53, 20772:50, 38695:48, 41501:9, 12089:12, 189:26, 7975:56, 34058:0, 25627:38, 18367:60, 12293:26, 33548:40, 18231:63, 24588:39, 62465:22, 43010:15, 43013:56, 24578:58, 8285:23, 53258:22, 19459:29, 51506:27, 25603:50, 16690:23, 1561:51, 8221:54, 63493:46, 18726:46, 21514:56, 30464:38, 51510:13, 16678:31, 44347:62, 5927:42, 32819:4, 42240:56, 12039:3, 35841:6, 63247:42, 18435:42, 16909:12, 41228:54, 26375:17, 32687:34, 44863:15, 48384:61, 38154:5, 5130:4, 11776:47, 37166:54, 24602:5, 64005:39, 19505:51, 10243:62, 57357:13, 16694:15, 53261:21, 12095:17, 13825:44, 57346:61, 27449:41, 44034:55, 4110:24, 9753:14, 39:24, 23077:34, 16957:10, 28687:11, 8972:30, 2050:20, 53263:3, 24603:17, 49165:30, 50737:3, 15363:3, 302:9, 33074:28, 49932:31, 3585:13, 14339:50, 16443:43, 2099:37, 16423:39, 53516:17, 1027:24, 51239:62, 17176:43, 32831:62, 61247:6, 12290:63, 39937:23, 8460:18, 18200:38, 8197:10, 55299:19, 61:51, 54538:0, 23808:19, 22319:49, 58124:11, 8733:48, 46090:1, 27453:55, 1807:34, 3378:44, 18690:5, 23041:41, 2047:13, 24065:31, 25356:23, 24579:48, 25093:24, 9307:58, 40962:24, 11266:44, 16437:20, 4271:60, 23040:50, 16920:56, 39716:5, 49190:41, 36902:1, 34687:9, 25602:26, 10079:21, 14095:41, 22786:31, 51253:40, 36877:28, 12801:20, 61452:8, 57602:61, 8217:35, 8194:41, 266:30, 39204:3, 9999:57, 45067:63, 42767:21, 10557:7, 11777:36, 32815:30, 49167:47, 9227:1, 6661:8, 16391:53, 4111:14, 45836:38, 30723:59, 29:48, 27071:16, 49676:17, 38951:48, 16945:2, 45070:49, 2358:31, 47617:1, 6438:10, 36401:14, 1585:59, 50235:31, 22566:43, 38913:12, 24607:35, 12295:37, 57869:62, 2354:34, 41740:34, 1330:47, 65327:31, 33849:11, 47106:58, 18599:16, 22535:5, 4099:10, 12291:47, 28684:26, 36146:14, 42776:11, 34615:2, 8204:29, 28674:14, 19458:54, 57351:53, 37668:54, 38950:10, 35329:17, 10555:3, 16399:19, 43015:46, 1034:45, 1051:7, 56323:45, 318:56, 30209:41, 3073:56, 24:61, 54028:12, 22530:16, 10245:31, 58650:17, 45066:10, 12556:60, 2561:44, 2565:25, 50983:1, 58:32, 2167:3, 16953:49, 51203:54, 24834:40, 91:12, 55809:5, 17714:33, 18742:58, 13824:13, 14639:5, 53249:15, 16447:0, 21260:61, 17411:23, 20279:27, 34305:36, 10:58, 2816:15, 26626:12, 11197:20, 310:17, 33034:9, 45580:43, 4108:10, 1074:11, 6182:26, 6309:30, 2086:7, 17085:27, 12032:6, 47621:5, 59707:53, 32781:14, 36876:54, 36911:3, 53761:9, 9728:23, 16398:4, 31237:9, 53542:41, 8223:5, 2053:28, 59709:8, 36865:50, 32783:4, 16901:33, 6144:33, 29197:55, 40972:60, 41497:19, 33817:5, 22567:12, 2:18, 44847:29, 49677:4, 282:6, 17212:14, 26943:29, 45322:39, 4134:26, 16387:48, 6183:1, 4644:39, 15616:23, 40989:3, 32887:30, 49466:15, 10015:2, 12812:61, 828:51, 16397:39, 45581:12, 57369:20, 33292:22, 255:32, 2102:29, 1338:10, 41987:27, 2609:28, 62220:38, 53:57, 12544:40, 28940:3, 2103:18, 17164:55, 37413:36, 32769:14, 1280:18, 33038:2, 23076:62, 1083:27, 1959:0, 20231:22, 62467:29, 6063:3, 1115:24, 23332:8, 8207:38, 17977:34, 26631:35, 4135:56, 36867:55, 33802:47, 27:16, 53031:0, 30471:28, 49215:44, 42266:54, 19714:18, 33086:53, 50999:14, 20746:19, 280:19, 52275:63, 1983:26, 6693:34, 9242:42, 63746:46, 59167:41, 2101:42, 52227:43, 61708:10, 34871:3, 268:5, 41995:10, 53047:29, 1049:25, 21770:47, 53797:24, 15360:53, 605:34, 57868:62, 3123:16, 50234:26, 63490:49, 63495:5, 16445:55, 20748:58, 57349:47, 49211:15, 25117:31, 8218:18, 16442:57, 15361:2, 54283:7, 55845:50, 25882:10, 13568:37, 16446:34, 49422:4, 20490:45, 306:47, 15104:50, 59160:37, 27906:32, 33036:43, 49164:39, 42264:49, 10553:26, 40991:59, 6149:61, 43525:25, 14:61, 12223:6, 9216:0, 57861:61, 8984:36, 32780:63, 61965:4, 6402:57, 270:63, 51251:56, 42783:34, 16411:19, 44035:54, 57359:59, 49689:63, 44927:26, 7426:6, 4900:56, 804:60, 8205:34, 8219:55, 4364:14, 24601:23, 24320:58, 1967:57, 60418:47, 126:8, 8709:14, 49166:34, 3072:33, 2055:14, 32830:20, 36903:21, 44345:16, 59:14, 10247:57, 51255:48, 33572:2, 60419:14, 30722:38, 61454:20, 16413:22, 12554:26, 34867:29, 23205:12, 23296:55, 21029:57, 40743:9, 33819:4, 40985:29, 2098:57, 16386:20, 16439:14, 4142:12, 22822:27, 20517:6, 8474:30, 32779:10, 29698:34, 26627:32, 28930:42, 6400:0, 20483:45, 59399:4, 41230:25, 26137:56, 35126:7, 569:44, 20655:20, 27651:7, 119:56, 40974:13, 2597:59, 18191:41, 9306:20, 11577:1, 65287:26, 57127:57, 33078:5, 16410:38, 701:2, 5131:59, 42497:53, 32806:53, 9474:9, 1792:58, 34098:45, 35365:21, 1919:15, 49446:10, 517:45, 65280:58, 32823:61, 9498:51, 62475:31, 14341:40, 33082:62, 537:54, 11065:4, 31746:28, 57885:40, 14343:5, 2342:43, 10559:41, 40967:4, 4645:33, 42011:22, 59151:30, 46593:24, 12079:27, 32778:7, 40963:31, 57371:37, 15873:58, 25625:56, 49214:53, 32559:60, 36910:31, 55590:7, 36:13, 53772:21, 61191:4, 127:4, 39425:42, 20391:60, 548:50, 4107:47, 36647:61, 35381:17, 49191:2, 25100:43, 32885:0, 24844:9, 7943:58, 35122:5, 57358:49, 48896:39, 16551:25, 9226:27, 31747:49, 50745:13, 59711:51, 12303:37, 23810:63, 16422:58, 15362:53, 13313:63, 34854:36, 34679:63, 13323:15, 5:1, 29954:42, 32805:20, 10685:60, 17688:39, 37644:2, 561:61, 29452:3, 51238:15, 12558:57, 37889:62, 47109:13, 38671:9, 3584:38, 13068:34, 9217:53, 17466:28, 16702:28, 33281:23, 9562:27, 24846:23, 12805:59, 25101:58, 45069:30, 8717:24, 792:50, 25113:22, 60731:39, 37899:47, 1370:31, 26392:18, 47107:10, 32827:33, 42242:15, 20263:49, 17945:13, 29706:10, 16575:35, 63:34, 536:30, 18434:36, 22017:25, 57614:33, 93:26, 3633:35, 49203:0, 61964:53, 34106:29, 28686:5, 30725:40, 35843:61, 20494:4, 18343:1, 4362:17, 42250:16, 53285:50, 47105:38, 15:35, 37388:52, 35620:58, 292:48, 45057:3, 33843:24, 28423:57, 12800:39, 9729:15, 34935:62, 7681:53, 49420:28, 29189:58, 4109:8, 34623:5, 4007:31, 34353:43, 17690:50, 49210:53, 44545:43, 4106:48, 33305:17, 22447:14, 47111:31, 55079:46, 24581:23, 95:44, 549:9, 39461:62, 47:43, 20774:0, 8797:0, 33851:48, 12546:31, 175:30, 21004:45, 59909:4, 57626:45, 10008:45, 3075:27, 42330:5, 25:21, 45569:62, 52785:34, 15872:58, 33850:36, 36878:17, 2725:19, 25880:28, 1073:49, 36901:23, 7936:19, 20017:61, 57373:34, 56321:35, 25626:28, 3:42, 41242:58, 14849:39, 14853:27, 768:17, 50179:63, 63491:50, 117:47, 40975:43, 23555:19, 346:55, 34361:51, 12298:44, 6145:10, 14087:60, 46863:6, 314:20, 60:61, 40965:28, 16949:35, 12302:54, 9984:43, 20492:2, 16396:28, 43266:16, 36663:13, 8206:63, 14080:22, 24589:33, 58905:9, 26:51, 49725:53, 23045:26, 61241:45, 17722:63, 27961:59, 32782:39, 4620:30, 59650:20, 17666:38, 3328:5, 42075:60, 55334:27, 49207:59, 12813:33, 3840:61, 42847:48, 53287:23, 3121:50, 6151:44, 52530:31, 41985:34, 48131:15, 4621:42, 61455:1, 33883:34, 2097:3, 14338:41, 513:47, 3330:0, 258:62, 2596:21, 64515:58, 16389:32, 20993:48, 4398:24, 1035:23, 26882:36, 33293:18, 20519:4, 32793:22, 41485:43, 33084:31, 37891:56, 6821:24, 50203:26, 37377:26, 20493:18];

    int[Pattern3] w;
    foreach (h, weight; _winner){
        w[from_hash(h)] = weight;
    }
    int[Pattern3] l;

    auto stats = Statistics(-8 * 7, 8 * 7);

    auto random_s = s;
    foreach (i; 0..20){
        random_s = monte_carlo.child_by_pattern3(random_s, l);
    }

    writeln(random_s);
    foreach (j; 0..100000){
        s = random_s;
        foreach (i; 0..35){
            s = monte_carlo.child_by_pattern3(s, w);
            //writeln(s);
            s = monte_carlo.child_by_pattern3(s, w);
            //writeln(s);
        }
        auto e = Board8();
        stats.add_value(controlled_liberty_score(s, e, e, e, e, e, e));
    }
    writeln(stats);

    return;

    /*
    int[Pattern3] freqs;
    State8[] children;
    Pattern3[] patterns;

    auto stats = Statistics(-8 * 7, 8 * 7);
    foreach (j; 0..1000){
        s = State8(rectangle8(width, height));
        foreach (i; 0..100){
            s.make_move(Board8(uniform(0, 8), uniform(0, 7)));
            s.children_with_pattern3(children, patterns);
            foreach (p; patterns){
                p.canonize;
                freqs[p] += 1;
            }
        }
        //writeln(s);
        auto e = Board8();
        stats.add_value(controlled_liberty_score(s, e, e, e, e, e, e));
    }
    int r = 0;
    Pattern3[] common_patterns;
    foreach (p, c; freqs){
        if (c > 5000){
            common_patterns ~= p;
            writeln(p);
            writeln(c);
            writeln;
            r++;
        }
    }
    writeln(r, "/", freqs.length);
    writeln(stats);
    */

    bool[Pattern3] uniques;
    foreach (type; 0..3){
        foreach (player; 0..256){
            foreach (opponent; 0..256){
                if (!(player & opponent)){
                    if (type == 1){
                        player |= 7;
                        opponent |= 7;
                    }
                    else if (type == 2){
                        player |= 47;
                        opponent |= 47;
                    }
                    auto p = Pattern3(player, opponent);
                    p.canonize;
                    uniques[p] = true;
                }
            }
        }
    }
    writeln(uniques.length);

    int[Pattern3][] pws;

    enum N = 8;

    foreach (i; 0..N){
        int[Pattern3] pw;
        foreach (p; uniques.byKey){
            pw[p] = uniform(0, 64);
        }
        pws ~= pw;
    }

    double[N][N] scores;
    foreach (i, pw1; pws){
        foreach (j, pw2; pws){
            if (i < j){
                auto score = compete(pw1, pw2);
                scores[i][j] = score;
                scores[j][i] = -score;
            }
            else if (i == j){
                scores[i][j] = 0;
            }
        }
    }

    writeln(scores);

    while(true) {
        double worst_score = double.infinity;
        size_t worst_index = 0;
        foreach (i; 0..N){
            double total = 0;
            foreach (j; 0..N){
                total += scores[i][j];
            }
            if (total < worst_score){
                worst_score = total;
                worst_index = i;
            }
        }
        int[Pattern3] pw2;
        foreach (p; uniques.byKey){
            pw2[p] = uniform(0, 64);
        }
        pws[worst_index] = pw2;
        foreach (i, pw1; parallel(pws)){
            if (i != worst_index){
                auto score = compete(pw1, pw2);
                scores[i][worst_index] = score;
                scores[worst_index][i] = -score;
            }
            else if (i == worst_index){
                scores[i][worst_index] = 0;
            }
        }
        foreach (i; 0..N){
            double total = 0;
            foreach (j; 0..N){
                total += scores[i][j];
            }
            writeln(scores[i], " ", total);
        }
        writeln;

        double best_score = -double.infinity;
        size_t best_index = 0;
        foreach (i; 0..N){
            double total = 0;
            foreach (j; 0..N){
                total += scores[i][j];
            }
            if (total > best_score){
                best_score = total;
                best_index = i;
            }
        }

        int[hash_t] winner;
        foreach (key, value; pws[best_index]){
            winner[key.toHash] = value;
        }
        //int[Pattern3] unif;
        //writeln(compete(pws[best_index], unif));
        writeln(best_index);
        writeln(winner);
    }

    /*
    auto n = new DirectMCNode8(s, node_pool);

    foreach (i; 0..100){
        //writeln(n);
        writeln(s);
        foreach (k; 0..100){
            n.expand(0.75);
        }
        //foreach (child; n.children){
        //    writeln(child.confidence);
        //}
        if (!n.children.length){
            break;
        }
        else {
            DirectMCNode8 best_child;
            bool is_balanced = false;
            size_t balancing_rounds = 0;
            while (balancing_rounds < 1){
                best_child = n.best_child(is_balanced);
                if (is_balanced){
                    break;
                }
                else {
                    n.expand(0);
                    balancing_rounds++;
                    //writeln("balancing...");
                    //foreach (child; n.children){
                    //    child.get_value;
                    //    writeln(child.lower_value, " ", child.upper_value, " ", child.progeny, " ", child.is_final);
                    //}
                }
            }
            writeln("Balancing rounds=", balancing_rounds);
            //foreach (child; n.children){
            //    child.get_value;
                //writeln(child.value, " ", child.progeny, " ", child.is_final);
            //}
            n = best_child;
            s = decanonize(s, n.state.state);
        }
    }
    */

    /*
    foreach (k; 0..500){
        foreach (i; 0..10000){
            n.sample;
        }
        writeln(n);
        foreach (child; n.children){
            writeln(" ", child.lower);
        }
        n.expand;
    }
    */

    /*
    auto prior = Likelyhood(-width * height, width * height);
    prior.bins[] = 1.0;
    auto n = new LikelyhoodNode8(s, prior, node_pool);

    foreach (k; 0..40){
        foreach (i; 0..15){
            foreach (j; 0..600){
                n.refine;
            }
            writeln(n);
            foreach (child; n.children){
                writeln(child.value);
            }

            //writeln(n.choose_child);
            writeln(n.prior);
            //writeln(n.prior.bins);
            //writeln(n.children[$-2].prior);
            //writeln(n.children[$-1].prior);
            //foreach (child; n.children[$-1].children){
            //    writeln(child.value);
            //}
        }
        n = n.best_child;
        if (n is null){
            break;
        }
    }
    */

    /*
    int i = 0;
    while (n.visits && n.children.length && i < 20){
        n = n.best_child;
        writeln(n);
        writeln(n.prior.bins);
        i++;
    }
    */

    /*
    auto a = Board11(0, 2);
    auto b = Board11(3234723127743788234UL, 21231223479387123UL, true) & Board11.FULL;
    auto c = Board11(1, 0);
    c.flood_into(b);
    writeln(c);
    foreach (i; 0..10000000){
        a = Board11(0, 2);
        a.flood_into(b);
        if (a != c){
            writeln(a);
        }
    }
    writeln(a);
    */

    //auto s = n.default_playout_statistics(10000);
    //writeln(s);

    /*
    foreach (j; 0..100){
        foreach (i; 0..1000){
            n.playout;
            //writeln("p");
        }
        //foreach (c; n.children){
        //    writeln("c:", c.value);
        //}
        writeln(n.statistics);
        writeln(n);
        //writeln(n.statistics.decay_average);
        //writeln(n.best_child);
        n = n.best_child;
    }
    */

    /*
    auto l = Likelyhood(-3, 4);
    l.add_value(2);
    l.add_value(2);
    l.add_value(3);
    auto n = negamax([l, l]);
    writeln(l);
    writeln(l.bins);
    writeln(n);
    writeln(n.bins);
    auto r = negamax_root(l, 3, 20);
    writeln(negamax([r, r, r]));
    */

    /*
    File file = File("networks/4x4_network_5.txt", "r");
    auto line = file.readln;
    auto network = Network8.from_string(line);
    */
    //writeln(network);
    /*
    //auto state = DefenseState8(rectangle8(4, 4));
    //fight(state, network, network, 0.01, 40, true);

    auto playing_area = rectangle8(4, 4);

    tournament(playing_area, network, 12, 1000, 0.01, 40, 0.01, 4);
    */

    //auto playing_area = rectangle8(4, 4);
    //auto network = Network8(playing_area, 3);

    //tournament(playing_area, network, 12, 2 * 10 * 6 * 15, 0.01, 100, 0.02, 6);

    //Board8 playing_area = rectangle8(4, 4);
    /*
    auto network = Network8(playing_area);
    network.activate(Board8(1, 1), Board8(), 0.01);
    writeln(network.input_layer.layer);
    writeln(network);
    writeln(network.get_sum);
    */
    //tournament(playing_area, 2, 12, 2000, 0.01, 40);

    /*
    Transposition[DefenseState8] empty;
    auto defense_transposition_table = &empty;

    Transposition[CanonicalState8] empty2;
    auto transposition_table = &empty2;

    auto s = State8(rectangle8(4, 4));
    s.make_move(Board8(1, 1));
    s.make_move(Board8(2, 2));
    s.make_move(Board8(1, 2));
    s.make_move(Board8(2, 1));

    auto ss = new SearchState8(s, transposition_table, defense_transposition_table);
    ss.iterative_deepening(1, 36);
    writeln(ss);
    */
    //ss.pc;
    //writeln(ss.children[0].children[0]);
    //ss.children[0].children[0].pc;

    /*
    print_constants;

    auto b = Board11(0, 4) | Board11(0, 5) | Board11(0, 6) | Board11(1, 5) | Board11(2, 5) | Board11(2, 6) | Board11(2, 7) | Board11(2, 8) | Board11(1, 8) | Board11(0, 8);
    auto c = b | Board11(3, 9);
    auto d = Board11(0, 4);
    d.flood_into(c);

    assert(d == b);

    writeln(b);
    writeln(c);
    writeln(d);
    */

    /*
    Board8 playing_area = rectangle8(8, 7) & ~ Board8(0, 0);
    Board8 player = Board8(3, 3) | Board8(3, 4) | Board8(3, 5);
    Board8 opponent = Board8(4, 3) | Board8(5, 4);

    auto g = Grid(playing_area, player, opponent);
    g.bouzy;
    writeln(g);
    writeln;
    g.divide_by_influence;

    writeln(g);
    writeln(g.score);
    writeln(heuristic_value(playing_area, player, opponent));
    */

    /*
    TreeNode8[CanonicalState8] empty;
    auto node_pool = &empty;

    auto t = new TreeNode8(rectangle8(5, 5), node_pool);

    //t.state.state.make_move(Board8(2, 2));
    //t.state.state.canonize;

    while (!t.is_leaf){
        //writeln(t.default_playout_statistics(6000));
        writeln(t.statistics);
        writeln(t);
        foreach (i; 0..30000){
            t.playout;
        }
        foreach (c; t.children){
            //writeln("Child:");
            //writeln(c);
            writeln(c.value, ", ", c.visits);
        }
        t = t.best_child;
    }
    */

    /*
    Transposition[DefenseState8] empty;
    auto defense_transposition_table = &empty;


    auto ds = new DefenseSearchState8(rectangle8(4, 3), defense_transposition_table);
    //ss.state.opponent = Board8(1, 0);
    ds.calculate_minimax_value(20);

    ds.ppp;
    */

    /+
    Transposition[DefenseState8] defense_transposition_table;

    foreach (eyespace; eyespaces(4).byKey){
        if (eyespace.space.length == 4){
            auto s = from_eyespace8(eyespace, false, -float.infinity);
            if (s.opponent_targets.length){
                s.opponent_targets[0].outside_liberties = 1;
            }
            auto ds = new DefenseSearchState8(s);
            ds.calculate_minimax_value;
            if (ds.lower_bound == ds.upper_bound){
                //writeln(s);
                //writeln(ds.lower_bound);
            }
            else{
                //writeln(ds);
            }
            /*
            Board8[] creating_moves;
            auto cs = s.children_and_moves(creating_moves);
            foreach (index, c; cs){
                auto cds = new DefenseSearchState8(c);
                cds.calculate_minimax_value;
                writeln(creating_moves[index]);
                writeln(cds.upper_bound);
            }
            */
        }
    }
    +/
}
