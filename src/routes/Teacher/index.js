import { injectReducer } from "../../store.js";

/**
 * Mirrors src/routes/routes/Teacher/index.js in the app.
 *
 * The two styles of require() below are the whole point of this repo:
 *
 *   OK      require("...").default   — a property is taken AT the require site
 *   BROKEN  require("...")           — the whole module object is captured,
 *                                      then properties are read off it later
 *
 * Both are valid. Both work on webpack 5.109.2. On 5.110.0+ the second form
 * emits an unsubstituted internal placeholder and throws at runtime.
 */
export default function makeTeacherRoute(store) {
  return {
    path: ":curriculumProgramId",
    load: () =>
      new Promise((resolve, reject) => {
        require.ensure(
          [],
          require => {
            // ---- these are fine: property taken at the require site ----
            const teacherReducer = require("../../modules/TeacherModule.js").default;
            injectReducer(store, { key: "teacher", reducer: teacherReducer });

            const classRoomReducer = require("../../modules/ClassRoomModule.js").default;
            injectReducer(store, { key: "classRoom", reducer: classRoomReducer });

            // ---- these break: whole module object captured ----
            const adminReducer = require("../../modules/AdministratorModule.js");
            const worksheetModule = require("../../modules/WorksheetModules.js");
            const portfolioReviewModule = require("../../modules/PortfolioReviewModule.js");
            const timeTablePlanner = require("../../modules/TimetablePlannerModule.js");

            injectReducer(store, {
              key: worksheetModule.NAME,
              reducer: worksheetModule.default,
            });
            injectReducer(store, {
              key: adminReducer.NAME,
              reducer: adminReducer.default,
            });
            injectReducer(store, {
              key: portfolioReviewModule.NAME,
              reducer: portfolioReviewModule.default,
            });
            injectReducer(store, {
              key: "timetablePlanner",
              reducer: timeTablePlanner.default,
            });

            resolve("teacher route loaded");
          },
          err => reject(err),
          "teacher"
        );
      }),
  };
}
